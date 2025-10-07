from pyflink.table import *
from pyflink.common import Configuration

def streaming():
    def create_remote_table_env():
        config = Configuration()
        config.set_string("jobmanager.rpc.address", "job-manager")
        config.set_string("jobmanager.rpc.port", "6123")
        config.set_string("rest.address", "job-manager")
        config.set_string("rest.port", "8081")
        config.set_string("execution.target", "remote")
        
        # Add timeout settings
        config.set_string("akka.ask.timeout", "10s")
        config.set_string("web.timeout", "10000")
        
        environment_settings = EnvironmentSettings \
            .new_instance() \
            .in_streaming_mode() \
            .with_configuration(config) \
            .build()
        
        try:
            table_env = TableEnvironment.create(environment_settings)
            print("Connected to remote Flink cluster")
            return table_env
        except Exception as e:
            print(f"Failed to connect: {e}")
            return None

    table_env = create_remote_table_env()
    # Source table
    source_ddl = """
        CREATE TABLE transactions(
            id VARCHAR,
            from_name VARCHAR,
            to_name VARCHAR,
            money DECIMAL(10,2),
            date_str VARCHAR,
            status INT,
            proc_time AS PROCTIME()
        ) WITH (
            'connector' = 'kafka',
            'topic' = 'transactions',
            'properties.bootstrap.servers' = 'kafka:9092',
            'properties.group.id' = 'transactions',
            'scan.startup.mode' = 'latest-offset',
            'format' = 'json'
        )
    """

    # Regular Kafka Sink (append-only)
    sink_ddl = """
        CREATE TABLE processed_transaction_kafka(
            id VARCHAR,
            from_name VARCHAR,
            to_name VARCHAR,
            money DECIMAL(10,2),
            date_str VARCHAR,
            status INT,
            daily_total DECIMAL(10,2),
            reason VARCHAR,
            processing_time TIMESTAMP(3)
        ) WITH (
            'connector' = 'kafka',
            'topic' = 'processed_transaction',
            'properties.bootstrap.servers' = 'kafka:9092',
            'format' = 'json'
        )
    """

    table_env.execute_sql(source_ddl)
    table_env.execute_sql(sink_ddl)

    # Temporarily simplified logic
    kafka_query = """
        INSERT INTO processed_transaction_kafka
        SELECT 
            id,
            from_name,
            to_name,
            money,
            date_str,
            CASE 
                WHEN status = 0 THEN 
                    CASE 
                        WHEN running_total > 1500.00 THEN 2  -- Conservative threshold
                        ELSE 1
                    END
                ELSE status
            END as status,
            running_total as daily_total,
            CASE 
                WHEN status = 0 AND running_total > 1500.00
                THEN 'BLOCKED: Approaching daily limit'
                WHEN status = 0 
                THEN 'SUCCESS: Transaction approved'
                ELSE 'NO_CHANGE: Status unchanged'
            END as reason,
            CURRENT_TIMESTAMP as processing_time
        FROM (
            SELECT 
                id,
                from_name,
                to_name,
                money,
                date_str,
                status,
                SUM(money) 
                    OVER (
                        PARTITION BY from_name, date_str 
                        ORDER BY proc_time 
                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                    ) as running_total
            FROM transactions
            WHERE status = 0  -- Only process pending transactions
        )
    """

    result = table_env.execute_sql(kafka_query)
    
    print("Transaction monitoring started...")

    job_client = result.get_job_client()
    if job_client:
        print(f"Job started: {job_client.get_job_id()}")
    
    print("Processing realtime data... (Press Ctrl+C to stop)")
    result.wait()  # Job sẽ xử lý data mới mãi mãi

if __name__ == '__main__':
    streaming()