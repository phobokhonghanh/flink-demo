# =====================================
# Kafka Custom Image (Bitnami based - KRaft mode)
# =====================================
FROM bitnami/kafka:3.5 AS kafka_custom
WORKDIR /opt/bitnami/kafka/
USER root

RUN apt-get update && apt-get install -y \
    curl netcat-openbsd telnet vim \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && mkdir -p /opt/bitnami/kafka/topics /opt/bitnami/kafka/data

COPY docker/kafka/create-topics.sh \
     docker/kafka/setup-kraft.sh \
     docker/kafka/docker-entrypoint-kraft.sh \
     ./

RUN chmod +x *.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD kafka-topics.sh --bootstrap-server localhost:9092 --list || exit 1

VOLUME ["/opt/bitnami/kafka/data"]
EXPOSE 9092 9093 9094
ENTRYPOINT ["/opt/bitnami/kafka/docker-entrypoint-kraft.sh"]

# =====================================
# Flink Custom Image 
# =====================================
FROM flink:1.17-scala_2.12-java11 AS flink_custom 
USER root
WORKDIR /opt/flink/

ENV FLINK_VERSION=1.17.1 \
    FLINK_CLASSPATH="/opt/flink/lib/*:/opt/flink/extra-lib/*"

# Cài đặt pip và các dependencies cần thiết
RUN apt update -y && \
    apt install -y python3-pip && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./requirements.txt /opt/flink/requirements.txt

RUN pip install -r /opt/flink/requirements.txt 

RUN wget -q https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/${FLINK_VERSION}/flink-sql-connector-kafka-${FLINK_VERSION}.jar \
    && wget -q https://repo1.maven.org/maven2/org/apache/flink/flink-json/${FLINK_VERSION}/flink-json-${FLINK_VERSION}.jar \
    && mv flink-sql-connector-kafka-${FLINK_VERSION}.jar /opt/flink/lib/ \
    && mv flink-json-${FLINK_VERSION}.jar /opt/flink/lib/

RUN mkdir -p /opt/flink/log \
    /opt/flink/jobs \
    /opt/flink/data/checkpoint \
    /opt/flink/data/delta-lake 

COPY . /opt/flink/
COPY docker/flink/flink-conf.yaml /opt/flink/conf/flink-conf.yaml

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8081/overview || exit 1

VOLUME ["/opt/flink/data/checkpoint", "/opt/flink/data/delta-lake"]

EXPOSE 8888 8081 6123 6122

#############################
# PyFlink Job Image
#############################
FROM python:3.11.9-slim-bullseye as pyjob-flink
WORKDIR /opt/itc
USER root
ENV FLINK_VERSION=1.17.1 \
    SCALA_VERSION=2.12 \
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    FLINK_HOME=/opt/flink \
    PATH=$FLINK_HOME/bin:$JAVA_HOME/bin:$PATH \
    PYTHONPATH=/opt/itc \
    FLINK_CLASSPATH="/opt/flink/lib/*:/opt/flink/extra-lib/*"

RUN apt-get update && apt-get install -y wget \
    openjdk-11-jre-headless maven \
    && rm -rf /var/lib/apt/lists/*

# Download và setup Flink
RUN wget -q https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz \
    && wget -q https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/${FLINK_VERSION}/flink-sql-connector-kafka-${FLINK_VERSION}.jar \
    && tar -xzf flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz -C /opt/ \
    && rm flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz \
    && mv /opt/flink-${FLINK_VERSION} /opt/flink \
    && mv flink-sql-connector-kafka-${FLINK_VERSION}.jar /opt/flink/lib/ \
    && mkdir -p /opt/flink/log \
    && chmod -R 755 /opt/flink

COPY ./requirements.txt /opt/itc/requirements.txt
RUN pip install --upgrade pip --no-cache-dir \
    && pip install -r /opt/itc/requirements.txt

COPY . /opt/itc

RUN mvn dependency:copy-dependencies \
    -DoutputDirectory=/opt/flink/extra-lib \
    -DexcludeGroupIds=org.apache.flink

EXPOSE 8082
RUN sh /opt/itc/scripts/build-project.sh
CMD ["python3", "scripts/init_package.py"]

# =====================================
# Monitoring Dashboard Custom Image
# =====================================
FROM python:3.9-slim AS monitoring_custom
WORKDIR /opt/itc/
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    iputils-ping \
    netcat-openbsd \
    telnet \
    dnsutils \
    net-tools \
    && rm -rf /var/lib/apt/lists/*
COPY ./requirements.txt .
RUN pip install -r requirements.txt
COPY monitoring/ .
RUN useradd -m -s /bin/bash app && chown -R app:app /opt/itc
USER app
EXPOSE 8080
ENV FLASK_APP=dashboard.py \
    FLASK_ENV=production \
    FLASK_DEBUG=false \
    PORT=8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--timeout", "120", "--reload", "--log-level", "info", "dashboard:app"]