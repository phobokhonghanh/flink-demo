# Colors for help
YELLOW := \033[33m
GREEN := \033[32m
RESET := \033[0m

# Initialize the cluster
init:
	@chmod +x scripts/*.sh
	@./scripts/init-cluster.sh

build-image:
	@echo "Build image"
	@./scripts/build_image.sh

deploy:
	@echo "Deploy"
	@docker stack deploy -c docker-compose.yml flink-demo

stop:
	@echo "Stopping stack flink-demo"
	@docker stack rm flink-demo

clean:
	@./scripts/cleanup.sh

status:
	@echo "Service Status:"
	@echo "=================="
	@docker service ls --filter label=com.docker.stack.namespace=flink-demo 2>/dev/null || echo "No services running"
	@echo ""
	@echo "Container Status:"
	@docker ps --filter label=com.docker.stack.namespace=flink-demo --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers running"
	@echo ""
	@echo "Node Status:"
	@docker node ls 2>/dev/null || echo "Not in swarm mode"

list-topic:
	@echo "list_topic"
	@KAFKA_CONTAINER=$$(docker ps -q --filter "name=kafka") && \
	docker exec $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092

list-group:
	@echo "Listing all Kafka consumer groups..."
	@KAFKA_CONTAINER=$$(docker ps -q --filter "name=kafka") && \
	if [ ! -z "$$KAFKA_CONTAINER" ]; then \
		docker exec -it $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-consumer-groups.sh \
			--bootstrap-server localhost:9092 \
			--list; \
	else \
		echo "Kafka container not found"; \
	fi

describe-group:
	@echo "Describe Kafka consumer group: $(GROUP)"
	@KAFKA_CONTAINER=$$(docker ps -q --filter "name=kafka") && \
	if [ ! -z "$$KAFKA_CONTAINER" ]; then \
		docker exec -it $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-consumer-groups.sh \
			--bootstrap-server localhost:9092 \
			--describe --group $(GROUP); \
	else \
		echo "Kafka container not found"; \
	fi

produce-transactions:
	@echo "Starting Kafka producer for topic: transactions"
	@KAFKA_CONTAINER=$$(docker ps -q --filter "name=kafka") && \
	if [ ! -z "$$KAFKA_CONTAINER" ]; then \
		docker exec -it $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-console-producer.sh \
			--bootstrap-server localhost:9092 \
			--topic transactions; \
	else \
		echo "Kafka container not found"; \
	fi

monitor-transactions:
	@echo "Monitoring transactions"
	@echo "=============================================="
	@KAFKA_CONTAINER=$$(docker ps -q --filter "name=kafka") && \
	if [ ! -z "$$KAFKA_CONTAINER" ]; then \
		echo "Topic info:" && \
		docker exec $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-topics.sh \
			--describe --topic transactions \
			--bootstrap-server localhost:9092 && \
		echo "\n================sc==============================" && \
		echo "Consuming data:" && \
		docker exec -it $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
			--bootstrap-server localhost:9092 \
			--topic transactions \
			--from-beginning \
			--max-messages 20; \
	else \
		echo "Kafka container not found"; \
	fi

monitor-processed_transaction:
	@echo "Monitoring transactions"
	@echo "=============================================="
	@KAFKA_CONTAINER=$$(docker ps -q --filter "name=kafka") && \
	if [ ! -z "$$KAFKA_CONTAINER" ]; then \
		echo "Topic info:" && \
		docker exec $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-topics.sh \
			--describe --topic processed_transaction \
			--bootstrap-server localhost:9092 && \
		echo "\n================sc==============================" && \
		echo "Consuming data:" && \
		docker exec -it $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
			--bootstrap-server localhost:9092 \
			--topic processed_transaction \
			--from-beginning \
			--max-messages 20; \
	else \
		echo "Kafka container not found"; \
	fi

reset-transactions-offsets:
	@echo "Resetting offsets for group: console-consumer-2769 (topic: transactions)"
	@KAFKA_CONTAINER=$$(docker ps -q --filter "name=kafka") && \
	if [ ! -z "$$KAFKA_CONTAINER" ]; then \
		docker exec -it $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-consumer-groups.sh \
			--bootstrap-server localhost:9092 \
			--group console-consumer-2769 \
			--reset-offsets --to-latest \
			--topic transactions --execute; \
	else \
		echo "Kafka container not found"; \
	fi


create-test-topic:
	@echo "Creating Kafka topic: test-topic"
	@KAFKA_CONTAINER=$$(docker ps -q --filter "name=kafka") && \
	if [ ! -z "$$KAFKA_CONTAINER" ]; then \
		docker exec -it $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-topics.sh \
			--create \
			--topic test-topic \
			--bootstrap-server localhost:9092 \
			--partitions 1 \
			--replication-factor 1; \
	else \
		echo "Kafka container not found"; \
	fi

produce-test:
	@echo "Starting Kafka producer for topic: test-topic"
	@KAFKA_CONTAINER=$$(docker ps -q --filter "name=kafka") && \
	if [ ! -z "$$KAFKA_CONTAINER" ]; then \
		docker exec -it $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-console-producer.sh \
			--bootstrap-server localhost:9092 \
			--topic test-topic; \
	else \
		echo "Kafka container not found"; \
	fi

monitor-test:
	@echo "Monitoring transactions"
	@echo "=============================================="
	@KAFKA_CONTAINER=$$(docker ps -q --filter "name=kafka") && \
	if [ ! -z "$$KAFKA_CONTAINER" ]; then \
		echo "Topic info:" && \
		docker exec $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-topics.sh \
			--describe --topic test-topic \
			--bootstrap-server localhost:9092 && \
		echo "\n==============================================" && \
		echo "Consuming data:" && \
		docker exec -it $$KAFKA_CONTAINER /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
			--bootstrap-server localhost:9092 \
			--topic test-topic \
			--from-beginning \
			--max-messages 20; \
	else \
		echo "Kafka container not found"; \
	fi