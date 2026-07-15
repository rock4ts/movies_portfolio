#!/bin/bash
set -e

echo "Initializing Kafka topics..."

BOOTSTRAP_SERVERS=${KAFKA_BOOTSTRAP_SERVERS:-kafka:9092}

IFS=';' read -ra TOPICS <<< "$TOPIC_CONFIGS"

for topic_config in "${TOPICS[@]}"; do
    IFS=',' read -r topic partitions replication_factor min_isr cleanup_policy retention_ms segment_ms <<< "$topic_config"

    if [[ -z "$topic" || -z "$partitions" || -z "$replication_factor" ]]; then
        echo "Invalid topic config: $topic_config"
        exit 1
    fi

    echo "Creating topic:"
    echo "  name=$topic"
    echo "  partitions=$partitions"
    echo "  replication_factor=$replication_factor"

    topic_settings=""
    if [[ -n "$min_isr" && -n "$cleanup_policy" && -n "$retention_ms" && -n "$segment_ms" ]]; then
        topic_settings="min.insync.replicas=$min_isr,cleanup.policy=$cleanup_policy,retention.ms=$retention_ms,segment.ms=$segment_ms"
        echo "configs=$topic_settings"
    fi

    if /opt/kafka/bin/kafka-topics.sh \
        --describe \
        --topic "$topic" \
        --bootstrap-server "$BOOTSTRAP_SERVERS" > /dev/null 2>&1
    then
        echo "Topic already exists: $topic"
        current_partitions=$(
            /opt/kafka/bin/kafka-topics.sh \
                --describe \
                --topic "$topic" \
                --bootstrap-server "$BOOTSTRAP_SERVERS" |
                awk -F'PartitionCount: ' 'NR == 1 { split($2, value, " "); print value[1] }'
        )

        if [[ "$current_partitions" -lt "$partitions" ]]; then
            /opt/kafka/bin/kafka-topics.sh \
                --alter \
                --topic "$topic" \
                --bootstrap-server "$BOOTSTRAP_SERVERS" \
                --partitions "$partitions"
        elif [[ "$current_partitions" -gt "$partitions" ]]; then
            echo "Cannot reduce $topic from $current_partitions to $partitions partitions"
            exit 1
        fi
    else
        /opt/kafka/bin/kafka-topics.sh \
            --create \
            --if-not-exists \
            --topic "$topic" \
            --bootstrap-server "$BOOTSTRAP_SERVERS" \
            --partitions "$partitions" \
            --replication-factor "$replication_factor"
    fi

    if [[ -n "$topic_settings" ]]; then
        /opt/kafka/bin/kafka-configs.sh \
            --alter \
            --entity-type topics \
            --entity-name "$topic" \
            --bootstrap-server "$BOOTSTRAP_SERVERS" \
            --add-config "$topic_settings"
    fi

    echo "Topic ready: $topic"
done

echo "Kafka topics initialized"
