#!/bin/bash
##
# Licensed to Cloudera, Inc. under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  Cloudera, Inc. licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# for debugging
set -x

DEFAULT_KAFKA_HOME=/usr/lib/kafka
KAFKA_HOME=${KAFKA_HOME:-$DEFAULT_KAFKA_HOME}
MIN_REFACTORED_MIRROR_MAKER_VERSION=2

# For better debugging
echo ""
echo "Date: `date`"
echo "Host: `hostname -f`"
echo "Pwd: `pwd`"
echo "CONF_DIR: $CONF_DIR"
echo "KAFKA_HOME: $KAFKA_HOME"
echo "Zookeeper Quorum: $ZK_QUORUM"
echo "Zookeeper Chroot: $CHROOT"
echo "no.data.loss: ${NO_DATA_LOSS}"
echo "whitelist: ${WHITELIST}"
echo "blacklist: ${BLACKLIST}"
echo "num.producers: ${NUM_PRODUCERS}"
echo "num.streams: ${NUM_STREAMS}"
echo "queue.size: ${QUEUE_SIZE}"
echo "queue.byte.size: ${QUEUE_BYTE_SIZE}"
echo "JMX_PORT: $JMX_PORT"
echo "MM_HEAP_SIZE: ${MM_HEAP_SIZE}"
echo "MM_JAVA_OPTS: ${MM_JAVA_OPTS}"
echo "abort.on.send.failure: ${ABORT_ON_SEND_FAILURE}"
echo "offset.commit.interval.ms: ${OFFSET_COMMIT_INTERVAL_MS}"
echo "consumer.rebalance.listener: ${CONSUMER_REBALANCE_LISTENER}"
echo "consumer.rebalance.listener.args: ${CONSUMER_REBALANCE_LISTENER_ARGS}"
echo "message.handler: ${MESSAGE_HANDLER}"
echo "message.handler.args: ${MESSAGE_HANDLER_ARGS}"
echo "SOURCE_SECURITY_PROTOCOL: ${SOURCE_SECURITY_PROTOCOL}"
echo "DESTINATION_SECURITY_PROTOCOL: ${DESTINATION_SECURITY_PROTOCOL}"
echo "KAFKA_MIRROR_MAKER_PRINCIPAL: ${KAFKA_MIRROR_MAKER_PRINCIPAL}"
echo "SOURCE_SSL_CLIENT_AUTH: ${SOURCE_SSL_CLIENT_AUTH}"
echo "DESTINATION_SSL_CLIENT_AUTH: ${DESTINATION_SSL_CLIENT_AUTH}"

KAFKA_VERSION=$(grep "^version=" $KAFKA_HOME/cloudera/cdh_version.properties | cut -d '=' -f 2)
KAFKA_MAJOR_VERSION=$(echo $KAFKA_VERSION | cut -d '-' -f 2 | sed 's/kafka//g' | cut -d '.' -f 1)
echo "Kafka version found: ${KAFKA_VERSION}"

if [[ -n ${WHITELIST} ]]; then
    WL_TOPICS="--whitelist ${WHITELIST}"
    echo "Using topic whitelist: ${WL_TOPICS}"
fi

if [[ -n ${NUM_STREAMS} ]]; then
    STREAM_PARAM="--num.streams ${NUM_STREAMS}"
fi

if [[ $KAFKA_MAJOR_VERSION < $MIN_REFACTORED_MIRROR_MAKER_VERSION ]]; then
    # Generating Zookeeper quorum
    QUORUM=$ZK_QUORUM
    if [[ -n $CHROOT ]]; then
        QUORUM="${QUORUM}${CHROOT}"
    fi
    echo "Final Zookeeper Quorum is $QUORUM"

    if ! grep zookeeper.connect= ${CONF_DIR}/mirror_maker_consumers.properties; then
        echo "zookeeper.connect=$QUORUM" >> ${CONF_DIR}/mirror_maker_consumers.properties
    fi

    if [[ ${NO_DATA_LOSS} == "true" ]]; then
        DATA_LOSS_PARAM="--no.data.loss"
    fi

    echo "data loss param: ${DATA_LOSS_PARAM}"

    if [[ -n ${BLACKLIST} ]]; then
        BL_TOPICS="--blacklist ${BLACKLIST}"
        echo "Using topic blacklist ${BL_TOPICS}"
    fi

    if [[ -n ${NUM_PRODUCERS} ]]; then
        PRODUCER_PARAM="--num.producers ${NUM_PRODUCERS}"
    fi

    if [[ -n ${QUEUE_SIZE} ]]; then
        QUEUE_SIZE_PARAM="--queue.size ${QUEUE_SIZE}"
    fi

    if [[ -n ${QUEUE_BYTE_SIZE} ]]; then
        QUEUE_BYTE_SIZE_PARAM="--queue.byte.size ${QUEUE_BYTE_SIZE}"
    fi
else
    if [[ -n ${ABORT_ON_SEND_FAILURE} ]]; then
        ABORT_ON_SEND_FAILURE_FLAG="--abort.on.send.failure ${ABORT_ON_SEND_FAILURE}"
    fi

    if [[ -n ${OFFSET_COMMIT_INTERVAL_MS} ]]; then
        OFFSET_COMMIT_INTERVAL_MS_PARAM="--offset.commit.interval.ms ${OFFSET_COMMIT_INTERVAL_MS}"
    fi

    if [[ -n ${CONSUMER_REBALANCE_LISTENER} ]]; then
        CONSUMER_REBALANCE_LISTENER_PARAM="--consumer.rebalance.listener ${CONSUMER_REBALANCE_LISTENER}"
        if [[ -n ${CONSUMER_REBALANCE_LISTENER_ARGS} ]]; then
            CONSUMER_REBALANCE_LISTENER_ARGS_PARAM="--consumer.rebalance.listener.args ${CONSUMER_REBALANCE_LISTENER_ARGS}"
        fi
    fi

    if [[ -n ${MESSAGE_HANDLER} ]]; then
        MESSAGE_HANDLER_PARAM="--message.handler ${MESSAGE_HANDLER}"
        if [[ -n ${MESSAGE_HANDLER_ARGS} ]]; then
            MESSAGE_HANDLER_ARGS_PARAM="--message.handler.args ${MESSAGE_HANDLER_ARGS}"
        fi
    fi

    if [[ ${SOURCE_SECURITY_PROTOCOL} == *"SSL"* ]]; then
        set +x
        # Append other ssl params from ssl.properties
        SSL_CONFIGS=$(cat ssl_client.properties)
        if [[ ${SOURCE_SSL_CLIENT_AUTH} == "true" ]]; then
            SSL_SERVER_CONFIGS=$(cat ssl_server.properties)
            SSL_CONFIGS="${SSL_CONFIGS}
${SSL_SERVER_CONFIGS}"
        fi

        # Replace SSL_CONFIGS's placeholder
        perl -pi -e "s#\#ssl.configs={{SSL_CONFIGS}}#${SSL_CONFIGS}#" $CONF_DIR/mirror_maker_consumers.properties
        set -x
    else
        # Remove SSL_CONFIGS's placeholder
        perl -pi -e "s#\#ssl.configs={{SSL_CONFIGS}}##" $CONF_DIR/mirror_maker_consumers.properties
    fi

    if [[ ${DESTINATION_SECURITY_PROTOCOL} == *"SSL"* ]]; then
        set +x
        # Append other ssl params from ssl.properties
        SSL_CONFIGS=$(cat ssl_client.properties)
        if [[ ${DESTINATION_SSL_CLIENT_AUTH} == "true" ]]; then
            SSL_SERVER_CONFIGS=$(cat ssl_server.properties)
            SSL_CONFIGS="${SSL_CONFIGS}
${SSL_SERVER_CONFIGS}"
        fi

        # Replace SSL_CONFIGS's placeholder
        perl -pi -e "s#\#ssl.configs={{SSL_CONFIGS}}#${SSL_CONFIGS}#" $CONF_DIR/mirror_maker_producers.properties
        set -x
    else
        # Remove SSL_CONFIGS's placeholder
        perl -pi -e "s#\#ssl.configs={{SSL_CONFIGS}}##" $CONF_DIR/mirror_maker_producers.properties
    fi

    if [[ ${SOURCE_SECURITY_PROTOCOL} == *"SASL"* || ${DESTINATION_SECURITY_PROTOCOL} == *"SASL"* ]]; then
        if [[ -z "${JAAS_CONFIGS}" ]]; then
            KEYTAB_FILE="${CONF_DIR}/kafka.keytab"
            JAAS_CONFIGS="KafkaClient {
    com.sun.security.auth.module.Krb5LoginModule required
    useKeyTab=true
    storeKey=true
    keyTab=\"$KEYTAB_FILE\"
    principal=\"$KAFKA_MIRROR_MAKER_PRINCIPAL\";
};"
        fi
        echo "${JAAS_CONFIGS}" > $CONF_DIR/jaas.conf

        export KAFKA_OPTS="${KAFKA_OPTS} -Djava.security.auth.login.config=${CONF_DIR}/jaas.conf"
    fi
fi

# Propagating logger information to Kafka
export KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:$CONF_DIR/log4j.properties"

# Set LOG_DIR to pwd as this directory exists and hence the underlaying run-kafka-class.sh won't try to create a new directory inside the parcel
export LOG_DIR=`pwd`

# Set heap size
if [ -z "$KAFKA_HEAP_OPTS" ]; then
    export KAFKA_HEAP_OPTS="-Xmx${MM_HEAP_SIZE}M"
else
    echo "KAFKA_HEAP_OPTS is already set."
fi

# Set java opts
if [ -z "$KAFKA_JVM_PERFORMANCE_OPTS" ]; then
    export KAFKA_JVM_PERFORMANCE_OPTS="${CSD_JAVA_OPTS} ${MM_JAVA_OPTS}"
else
    echo "KAFKA_JVM_PERFORMANCE_OPTS is already set."
fi

# And finally run Kafka MirrorMaker itself
if [[ $KAFKA_MAJOR_VERSION < $MIN_REFACTORED_MIRROR_MAKER_VERSION ]]; then
    exec $KAFKA_HOME/bin/kafka-mirror-maker.sh --new.producer ${WL_TOPICS} ${BL_TOPICS} ${DATA_LOSS_PARAM} ${PRODUCER_PARAM} ${STREAM_PARAM} ${QUEUE_SIZE_PARAM} ${QUEUE_BYTE_SIZE_PARAM} --consumer.config $CONF_DIR/mirror_maker_consumers.properties --producer.config $CONF_DIR/mirror_maker_producers.properties
else
    exec $KAFKA_HOME/bin/kafka-mirror-maker.sh ${ABORT_ON_SEND_FAILURE_FLAG} ${WL_TOPICS} --new.consumer ${STREAM_PARAM} ${OFFSET_COMMIT_INTERVAL_MS_PARAM} ${CONSUMER_REBALANCE_LISTENER_PARAM} ${CONSUMER_REBALANCE_LISTENER_ARGS_PARAM} ${MESSAGE_HANDLER_PARAM} ${MESSAGE_HANDLER_ARGS_PARAM} --consumer.config $CONF_DIR/mirror_maker_consumers.properties --producer.config $CONF_DIR/mirror_maker_producers.properties
fi
