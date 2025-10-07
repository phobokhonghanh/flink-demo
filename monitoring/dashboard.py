import json
from jinja2 import TemplateNotFound
import requests
import time
import os
from flask import Flask, render_template, jsonify
from kafka import KafkaConsumer
import threading
from collections import defaultdict, deque
import logging

app = Flask(__name__)

# Setup logging
def setup_logging():
    # Create logger
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)
    
    # Formatter
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    
    # Console handler (for docker logs)
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # File handler
    log_file = '/opt/itc/dashboard.log'
    try:
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.INFO)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
        logger.info(f"Logging to file: {log_file}")
    except Exception as e:
        logger.error(f"Cannot create log file {log_file}: {e}")
    
    return logger

logger = setup_logging()
class TransactionMonitor:
    def __init__(self):
        self.flink_jobmanager_url = os.getenv('FLINK_JOBMANAGER_URL', 'http://flink-jobmanager:8081')
        self.kafka_bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
        
        self.transaction_stats = {
            'total_count': 0,
            'success_count': 0,
            'blocked_count': 0,
            'processing_rate': 0,
            'recent_transactions': deque(maxlen=100),
            'blocked_transactions': deque(maxlen=50),
            'daily_stats': defaultdict(lambda: {
                'from_name': '',
                'total_successful': 0.0,
                'transaction_count': 0,
                'blocked_count': 0,
                'last_update': time.time()
            }),
            'last_update': time.time(),
            'status': 'starting'
        }
        
        logger.info(f"Initializing TransactionMonitor with Kafka: {self.kafka_bootstrap_servers}")
        logger.info(f"Flink JobManager URL: {self.flink_jobmanager_url}")
        
        # Start background threads
        self.start_input_transaction_consumer()
        self.start_processed_transaction_consumer()
        
    def start_input_transaction_consumer(self):
        """Monitor incoming raw transactions"""
        def consume_input_transactions():
            try:
                consumer = KafkaConsumer(
                    'transactions',  # Input topic
                    bootstrap_servers=self.kafka_bootstrap_servers,
                    value_deserializer=lambda x: json.loads(x.decode('utf-8')),
                    # consumer_timeout_ms=1000,
                    auto_offset_reset='earliest',
                    group_id='dashboard-input-monitor'
                )
                
                logger.info("Input transaction consumer started")
                last_count_time = time.time()
                transaction_count_window = 0
                
                for message in consumer:
                    try:
                        transaction = message.value
                        self.transaction_stats['total_count'] += 1
                        transaction_count_window += 1
                        
                        # Calculate processing rate every minute
                        current_time = time.time()
                        if current_time - last_count_time >= 60:  # Every minute
                            self.transaction_stats['processing_rate'] = transaction_count_window
                            transaction_count_window = 0
                            last_count_time = current_time
                        
                        self.transaction_stats['last_update'] = current_time
                        self.transaction_stats['status'] = 'running'
                        
                    except Exception as e:
                        logger.error(f"Error processing input transaction: {e}")
                        
            except Exception as e:
                logger.error(f"Error in input transaction consumer: {e}")
                self.transaction_stats['status'] = 'error'
        
        thread = threading.Thread(target=consume_input_transactions, daemon=True)
        thread.start()
        
    def start_processed_transaction_consumer(self):
        """Monitor processed transactions from Flink output"""
        def consume_processed_transactions():
            try:
                consumer = KafkaConsumer(
                    'processed_transaction',  # Output topic from Flink
                    bootstrap_servers=self.kafka_bootstrap_servers,
                    value_deserializer=lambda x: json.loads(x.decode('utf-8')),
                    # consumer_timeout_ms=1000,
                    auto_offset_reset='earliest',
                    group_id='dashboard-processed-monitor'
                )
                
                logger.info("Processed transaction consumer started")
                
                for message in consumer:
                    try:
                        transaction = message.value
                        
                        # Update statistics based on status
                        status = transaction.get('status', 0)
                        from_name = transaction.get('from_name', 'Unknown')
                        to_name = transaction.get('to_name', 'Unknown')
                        money = float(transaction.get('money', 0))
                        date_str = transaction.get('date_str', 'Unknown')
                        daily_total = float(transaction.get('daily_total', 0))
                        reason = transaction.get('reason', 'No reason')
                        
                        # Count by status
                        if status == 1:
                            self.transaction_stats['success_count'] += 1
                        elif status == 2:
                            self.transaction_stats['blocked_count'] += 1
                        
                        # Add to recent transactions
                        transaction_info = {
                            'id': transaction.get('id'),
                            'from_name': from_name,
                            'to_name': to_name,
                            'money': money,
                            'date_str': date_str,
                            'status': status,
                            'status_text': self.get_status_text(status),
                            'daily_total': daily_total,
                            'reason': reason,
                            'timestamp': time.time()
                        }
                        
                        self.transaction_stats['recent_transactions'].append(transaction_info)
                        
                        # Track blocked transactions separately
                        if status == 2:
                            self.transaction_stats['blocked_transactions'].append(transaction_info)
                            logger.warning(f"Transaction blocked: {from_name} -> {to_name}: ${money} (Daily total: ${daily_total})")
                        
                        # Update daily stats per user
                        user_key = f"{from_name}_{date_str}"
                        daily_stat = self.transaction_stats['daily_stats'][user_key]
                        daily_stat['from_name'] = from_name
                        daily_stat['date'] = date_str
                        daily_stat['transaction_count'] += 1
                        daily_stat['last_update'] = time.time()
                        
                        if status == 1:
                            daily_stat['total_successful'] = daily_total + money  # Add current transaction
                        elif status == 2:
                            daily_stat['blocked_count'] += 1
                            daily_stat['total_successful'] = daily_total  # Don't add blocked amount
                        
                        logger.info(f"Processed transaction: {from_name} -> {to_name}: ${money} (Status: {status})")
                        
                    except Exception as e:
                        logger.error(f"Error processing transaction message: {e}")
                        
            except Exception as e:
                logger.error(f"Error in processed transaction consumer: {e}")
        
        thread = threading.Thread(target=consume_processed_transactions, daemon=True)
        thread.start()
    
    def get_status_text(self, status):
        """Convert status code to readable text"""
        status_map = {
            0: "Pending",
            1: "Success", 
            2: "Blocked"
        }
        return status_map.get(status, "Unknown")
    
    def get_flink_jobs(self):
        """Get Flink jobs"""
        try:
            response = requests.get(f"{self.flink_jobmanager_url}/jobs", timeout=5)
            return response.json()
        except Exception as e:
            logger.error(f"Error getting Flink jobs: {e}")
            return {"jobs": []}
    
    def get_flink_cluster_overview(self):
        """Get Flink cluster overview"""
        try:
            response = requests.get(f"{self.flink_jobmanager_url}/overview", timeout=5)
            return response.json()
        except Exception as e:
            logger.error(f"Error getting Flink overview: {e}")
            return {}

# Initialize monitor
monitor = TransactionMonitor()

@app.route('/')
def dashboard():
    """Main dashboard page"""
    try:
        return render_template('index.html')
    except TemplateNotFound:
        return "Template index.html not found!", 404
    except Exception as e:
        return f"Error: {str(e)}", 500
    
@app.route('/health')
def health_check():
    """Health check endpoint"""
    try:
        status = monitor.transaction_stats['status']
        last_update = monitor.transaction_stats['last_update']
        current_time = time.time()
        
        is_healthy = (current_time - last_update < 300) or status == 'starting'
        
        return jsonify({
            "status": "healthy" if is_healthy else "unhealthy",
            "monitor_status": status,
            "last_update": last_update,
            "timestamp": current_time,
            "total_transactions": monitor.transaction_stats['total_count'],
            "success_count": monitor.transaction_stats['success_count'],
            "blocked_count": monitor.transaction_stats['blocked_count'],
            "uptime": current_time - app.start_time if hasattr(app, 'start_time') else 0
        }), 200 if is_healthy else 503
        
    except Exception as e:
        logger.error(f"Health check error: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
            "timestamp": time.time()
        }), 503

@app.route('/api/flink/jobs')
def api_flink_jobs():
    """Get Flink jobs"""
    return jsonify(monitor.get_flink_jobs())

@app.route('/api/flink/overview')
def api_flink_overview():
    """Get Flink cluster overview"""
    return jsonify(monitor.get_flink_cluster_overview())

@app.route('/api/stats')
def api_stats():
    """Get transaction statistics"""
    stats = dict(monitor.transaction_stats)
    stats['recent_transactions'] = list(stats['recent_transactions'])
    stats['blocked_transactions'] = list(stats['blocked_transactions'])
    
    # Convert daily_stats to list format
    daily_stats_list = []
    for key, value in stats['daily_stats'].items():
        daily_stats_list.append(value)
    stats['daily_stats'] = daily_stats_list
    
    return jsonify(stats)

@app.route('/api/blocked-transactions')
def api_blocked_transactions():
    """Get recent blocked transactions"""
    return jsonify(list(monitor.transaction_stats['blocked_transactions']))

@app.route('/api/recent-transactions')
def api_recent_transactions():
    """Get recent transactions"""
    return jsonify(list(monitor.transaction_stats['recent_transactions']))

@app.route('/api/daily-summary')
def api_daily_summary():
    """Get daily summary by user"""
    daily_stats = []
    for key, value in monitor.transaction_stats['daily_stats'].items():
        daily_stats.append(value)
    
    return jsonify(sorted(daily_stats, key=lambda x: x['last_update'], reverse=True))

@app.route('/api/user-summary/<from_name>')
def api_user_summary(from_name):
    """Get summary for specific user"""
    user_stats = []
    for key, value in monitor.transaction_stats['daily_stats'].items():
        if value['from_name'] == from_name:
            user_stats.append(value)
    
    return jsonify(sorted(user_stats, key=lambda x: x['date'], reverse=True))

# Add startup timestamp
app.start_time = time.time()

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Starting transaction dashboard on port {port}, debug={debug}")
    logger.info("Endpoints available:")
    logger.info("  GET /              - Main dashboard")
    logger.info("  GET /health        - Health check")
    logger.info("  GET /api/stats     - Transaction statistics")
    logger.info("  GET /api/blocked-transactions - Recent blocked transactions")
    logger.info("  GET /api/daily-summary - Daily summary by user")
    
    app.run(host='0.0.0.0', port=port, debug=debug, threaded=True)