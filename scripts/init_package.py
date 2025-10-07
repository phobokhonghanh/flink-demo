import os
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import EnvironmentSettings, TableEnvironment

# ---- Khởi tạo Flink environment ----
env = StreamExecutionEnvironment.get_execution_environment()
settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
table_env = TableEnvironment.create(environment_settings=settings)

# ---- Add tất cả jar vào runtime ----
jars_dir = "/opt/flink/extra-lib"

pipeline_jars = [
    f"file://{os.path.join(jars_dir, f)}"
    for f in os.listdir(jars_dir) if f.endswith(".jar")
]

env.add_jars(*pipeline_jars)
table_env.get_config().get_configuration().set_string(
    "pipeline.jars", ";".join(pipeline_jars)
)

print("✅ PyFlink environment ready with Maven jars")

# ---- Test nhỏ ----
ds = env.from_collection([(1, "a"), (2, "b")])
ds.print()

env.execute("pyflink_job_with_maven_downloaded_jars")
