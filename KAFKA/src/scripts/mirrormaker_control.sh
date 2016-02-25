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

# For better debugging
echo ""
echo "Date: `date`"
echo "Host: `hostname -f`"
echo "Pwd: `pwd`"
echo "CONF_DIR: $CONF_DIR"
echo "KAFKA_HOME: $KAFKA_HOME"
echo "Zoookeper Quorum: $ZK_QUORUM"
echo "Chroot: $CHROOT"
echo "no.data.loss: ${NO_DATA_LOSS}"
echo "whitelist: ${WHITELIST}"
echo "blacklist: ${BLACKLIST}"
echo "num.producers: ${NUM_PRODUCERS}"
echo "num.streams: ${NUM_STREAMS}"
echo "queue.size: ${QUEUE_SIZE}"
echo "JMX_PORT: $JMX_PORT"

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

if [[ -n ${WHITELIST} ]]; then
    WL_TOPICS="--whitelist ${WHITELIST}"
    echo "Using topic whitelist: ${WL_TOPICS}"
fi

if [[ -n ${BLACKLIST} ]]; then
    BL_TOPICS="--blacklist ${BLACKLIST}"
    echo "Using topic blacklist ${BL_TOPICS}"
fi

if [[ -n ${NUM_PRODUCERS} ]]; then
    PRODUCER_PARAM="--num.producers ${NUM_PRODUCERS}"
fi

if [[ -n ${NUM_STREAMS} ]]; then
    STREAM_PARAM="--num.streams ${NUM_STREAMS}"
fi

if [[ -n ${QUEUE_SIZE} ]]; then
    QUEUE_SIZE_PARAM="--queue.size ${QUEUE_SIZE}"
fi

if [[ -n ${QUEUE_BYTE_SIZE} ]]; then
    QUEUE_BYTE_SIZE_PARAM="--queue.byte.size ${QUEUE_BYTE_SIZE}"
fi

# Propoagating logger information to Kafka
export KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:$CONF_DIR/log4j.properties"

# Set LOG_DIR to pwd as this directory exists and hence the underlaying run-kafka-class.sh won't try to create a new directory inside the parcel
export LOG_DIR=`pwd`

# And finally run Kafka MirrorMaker itself
exec $KAFKA_HOME/bin/kafka-mirror-maker.sh --new.producer ${WL_TOPICS} ${BL_TOPICS} ${DATA_LOSS_PARAM} ${PRODUCER_PARAM} ${STREAM_PARAM} ${QUEUE_SIZE_PARAM} ${QUEUE_BYTE_SIZE_PARAM} --consumer.config $CONF_DIR/mirror_maker_consumers.properties --producer.config $CONF_DIR/mirror_maker_producers.properties