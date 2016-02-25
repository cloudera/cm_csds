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

# For better debugging
echo ""
echo "Date: `date`"
echo "Host: `hostname -f`"
echo "Pwd: `pwd`"
echo "CONF_DIR: $CONF_DIR"
echo "KAFKA_HOME: $KAFKA_HOME"
echo "Zoookeper Quorum: $ZK_QUORUM"
echo "Chroot: $CHROOT"
echo "JMX_PORT: $JMX_PORT"
echo "ENABLE_MONITORING: ${ENABLE_MONITORING}"
echo "METRIC_REPORTERS: ${METRIC_REPORTERS}"
echo "BROKER_HEAP_SIZE: ${BROKER_HEAP_SIZE}"

# Generating Zookeeper quorum
QUORUM=$ZK_QUORUM
if [[ -n $CHROOT ]]; then
	QUORUM="${QUORUM}${CHROOT}"
fi
echo "Final Zookeeper Quorum is $QUORUM"

if ! grep zookeeper.connect= ${CONF_DIR}/kafka.properties; then
    echo "zookeeper.connect=$QUORUM" >> ${CONF_DIR}/kafka.properties
fi

# Add monitoring parameters - note that if any of the jars in kafka.metrics.reporters is missing, Kafka will fail to start
if [[ ${ENABLE_MONITORING} == "true" ]]; then
    echo "kafka.metrics.reporters=${METRIC_REPORTERS}" >>  $CONF_DIR/kafka.properties
fi


# Propoagating logger information to Kafka
export KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:$CONF_DIR/log4j.properties"

# Set LOG_DIR to pwd as this directory exists and hence the underlaying run-kafka-class.sh won't try to create a new directory inside the parcel
export LOG_DIR=`pwd`

# Set heap size
export KAFKA_HEAP_OPTS="-Xmx${BROKER_HEAP_SIZE}M"

# Set java opts
export KAFKA_JVM_PERFORMANCE_OPTS="${BROKER_JAVA_OPTS}"

# And finally run Kafka itself
exec $KAFKA_HOME/bin/kafka-server-start.sh $CONF_DIR/kafka.properties
