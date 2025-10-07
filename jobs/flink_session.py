from pyflink.table import EnvironmentSettings, TableEnvironment
from pyflink.common import Configuration


class FlinkSession:
    """
    FlinkSession class tương tự như SparkSession
    Để tạo session kết nối đến Flink cluster
    """
    
    def __init__(self, execution_mode="streaming"):
        self.table_env = None
        self.stream_env = None
        self.execution_mode = execution_mode
        
    @classmethod
    def builder(cls):
        return FlinkSessionBuilder()
    
    def sql(self, query):
        """Execute SQL query"""
        return self.table_env.sql_query(query)
    
    def execute_sql(self, sql):
        """Execute SQL statement"""
        return self.table_env.execute_sql(sql)
    
    def stop(self):
        """Stop the session"""
        print("Flink session stopped")

class FlinkSessionBuilder:
    """
    FlinkSessionBuilder class tương tự như SparkSession.builder
    """
    
    def __init__(self):
        self.app_name = "PyFlink Application"
        self.master_url = None
        self.config = Configuration()
        self.jars = []
        self.execution_mode = "streaming"  # Default to streaming
        
    def appName(self, name):
        """Set application name"""
        self.app_name = name
        return self
    
    def master(self, master_url):
        """Set master URL - format: flink://jobmanager:port"""
        self.master_url = master_url
        # Parse master URL
        if master_url.startswith("flink://"):
            jobmanager_address = master_url.replace("flink://", "").split(":")[0]
            jobmanager_port = master_url.replace("flink://", "").split(":")[1] if ":" in master_url else "6123"
            
            # Configure for remote execution
            self.config.set_string("jobmanager.rpc.address", jobmanager_address)
            self.config.set_string("jobmanager.rpc.port", jobmanager_port)
            self.config.set_string("rest.address", jobmanager_address)
            self.config.set_string("rest.port", "8081")  # Default REST port
            self.config.set_string("execution.target", "remote")
        return self
    
    def conf(self, key, value):
        """Set configuration"""
        self.config.set_string(key, value)            
        return self
    
    def enableBatchMode(self):
        """Enable batch execution mode"""
        self.execution_mode = "batch"
        return self
    
    def enableStreamingMode(self):
        """Enable streaming execution mode (default)"""
        self.execution_mode = "streaming"
        return self
    
    def getOrCreate(self):
        """Create or get existing Flink session"""
        try:
            # Create environment settings based on execution mode
            if self.execution_mode == "batch":
                settings = EnvironmentSettings.new_instance() \
                    .in_batch_mode() \
                    .with_configuration(self.config) \
                    .build()
                print(f"Running in BATCH mode")
            else:
                settings = EnvironmentSettings.new_instance() \
                    .in_streaming_mode() \
                    .with_configuration(self.config) \
                    .build()
                print(f"Running in STREAMING mode")
            
            # Create table environment
            table_env = TableEnvironment.create(settings)
            
            # Create session object
            session = FlinkSession(self.execution_mode)
            session.table_env = table_env
            
            print(f"Created Flink session: {self.app_name}")
            if self.master_url:
                print(f"Connected to: {self.master_url}")
            print(f"JARs loaded: {len(self.jars)}")
            
            return session
            
        except Exception as e:
            print(f"Failed to create Flink session: {e}")
            raise
