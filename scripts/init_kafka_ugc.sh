#!/bin/bash
set -e

echo "Initializing Kafka topics..."

BOOTSTRAP_SERVER=${KAFKA_BOOTSTRAP_SERVER:-kafka:9092}

IFS=';' read -ra TOPICS <<< "$TOPIC_CONFIGS"

for topic_config in "${TOPICS[@]}"; do
    IFS=',' read -r topic partitions replication_factor <<< "$topic_config"

    if [[ -z "$topic" || -z "$partitions" || -z "$replication_factor" ]]; then
        echo "Invalid topic config: $topic_config"
        exit 1
    fi

    echo "Creating topic:"
    echo "  name=$topic"
    echo "  partitions=$partitions"
    echo "  replication_factor=$replication_factor"

    if /opt/kafka/bin/kafka-topics.sh \
        --describe \
        --topic "$topic" \
        --bootstrap-server "$BOOTSTRAP_SERVER" > /dev/null 2>&1
    then
        echo "Topic already exists: $topic"
        continue
    fi

    /opt/kafka/bin/kafka-topics.sh \
        --create \
        --if-not-exists \
        --topic "$topic" \
        --bootstrap-server "$BOOTSTRAP_SERVER" \
        --partitions "$partitions" \
        --replication-factor "$replication_factor"

    if [[ $? -ne 0 ]]; then
        echo "Failed to create topic: $topic"
        exit 1
    fi

    echo "Topic created: $topic"
done

echo "Kafka topics initialized"
