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
MIN_KAFKA_MAJOR_VERSION_WITH_SSL=2

# For better debugging
echo ""
echo "Date: `date`"
echo "Host: $HOST"
echo "Pwd: `pwd`"
echo "CONF_DIR: $CONF_DIR"
echo "KAFKA_HOME: $KAFKA_HOME"
echo "Zoookeper Quorum: $ZK_QUORUM"
echo "Chroot: $CHROOT"
echo "PORT: $PORT"
echo "JMX_PORT: $JMX_PORT"
echo "SSL_PORT: $SSL_PORT"
echo "ENABLE_MONITORING: ${ENABLE_MONITORING}"
echo "METRIC_REPORTERS: ${METRIC_REPORTERS}"
echo "BROKER_HEAP_SIZE: ${BROKER_HEAP_SIZE}"
echo "KERBEROS_AUTH_ENABLED: ${KERBEROS_AUTH_ENABLED}"
echo "KAFKA_PRINCIPAL: ${KAFKA_PRINCIPAL}"
echo "SECURITY_INTER_BROKER_PROTOCOL: ${SECURITY_INTER_BROKER_PROTOCOL}"
echo "AUTHENTICATE_ZOOKEEPER_CONNECTION: ${AUTHENTICATE_ZOOKEEPER_CONNECTION}"

if [[ -z ${ZK_PRINCIPAL_NAME} ]]; then
    ZK_PRINCIPAL_NAME="zookeeper"
fi
echo "ZK_PRINCIPAL_NAME: ${ZK_PRINCIPAL_NAME}"

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

# Add SSL parameters
if [[ ${BROKER_SSL_ENABLED} == "true" ]]; then
    # Make sure kafka version is greater than or equal to 2.0.0
    if [[ ! -f $KAFKA_HOME/cloudera/cdh_version.properties ]]; then
        echo "$KAFKA_HOME/cloudera/cdh_version.properties not found. Assuming older version of Kafka is being used that does not support SSL."
        exit 1
    else
        KAFKA_VERSION=$(grep "^version=" $KAFKA_HOME/cloudera/cdh_version.properties | cut -d '=' -f 2)
        KAFKA_MAJOR_VERSION=$(echo $KAFKA_VERSION | cut -d '-' -f 2 | sed 's/kafka//g' | cut -d '.' -f 1)
        if [[ $KAFKA_MAJOR_VERSION < $MIN_KAFKA_MAJOR_VERSION_WITH_SSL ]]; then
            echo "Kafka version, $KAFKA_VERSION, does not support SSL"
            exit 1
        fi
    fi

    set +x
    # Append other ssl params from ssl.properties
    SSL_CONFIGS=$(cat ssl.properties)

    # If user has not provided safety valve, replace SSL_CONFIGS's placeholder
    perl -pi -e "s#\#ssl.configs={{SSL_CONFIGS}}#${SSL_CONFIGS}#" $CONF_DIR/kafka.properties
    set -x
fi

# Generate JAAS config file
if [[ ${KERBEROS_AUTH_ENABLED} == "true" ]]; then
    # If user has not provided safety valve, replace JAAS_CONFIGS's placeholder
    if [ -z "$JAAS_CONFIGS" ]; then
        KEYTAB_FILE="${CONF_DIR}/kafka.keytab"
        JAAS_CONFIGS="
KafkaServer {
   com.sun.security.auth.module.Krb5LoginModule required
   doNotPrompt=true
   useKeyTab=true
   storeKey=true
   keyTab=\"$KEYTAB_FILE\"
   principal=\"$KAFKA_PRINCIPAL\";
};
"
        if [[ ${AUTHENTICATE_ZOOKEEPER_CONNECTION} == "true" ]]; then
            JAAS_CONFIGS="${JAAS_CONFIGS}

Client {
   com.sun.security.auth.module.Krb5LoginModule required
   useKeyTab=true
   storeKey=true
   keyTab=\"$KEYTAB_FILE\"
   principal=\"$KAFKA_PRINCIPAL\";
};"
        fi
    fi
    echo "${JAAS_CONFIGS}" > $CONF_DIR/jaas.conf
fi


# Security protocol to be used
SECURITY_PROTOCOL=""
if [[ ${KERBEROS_AUTH_ENABLED} == "true" ]]; then
    if [[ ${BROKER_SSL_ENABLED} == "true" ]]; then
        SECURITY_PROTOCOL="SASL_SSL"
    else
        SECURITY_PROTOCOL="SASL_PLAINTEXT"
    fi
else
    if [[ ${BROKER_SSL_ENABLED} == "true" ]]; then
        SECURITY_PROTOCOL="SSL"
    else
        SECURITY_PROTOCOL="PLAINTEXT"
    fi
fi


# Add listeners
LISTENERS="listeners="
if [[ ${BROKER_SSL_ENABLED} == "true" ]]; then
    LISTENERS="${LISTENERS}${SECURITY_PROTOCOL}://${HOST}:${SSL_PORT},"
else
    LISTENERS="${LISTENERS}${SECURITY_PROTOCOL}://${HOST}:${PORT},"
fi
if [[ ${SECURITY_INTER_BROKER_PROTOCOL} != ${SECURITY_PROTOCOL} ]]; then
    # Verify SSL or SASL can be set, if included in security.inter.broker.protocol
    if [[ ${SECURITY_INTER_BROKER_PROTOCOL} == *"SSL"* && ${BROKER_SSL_ENABLED} != "true" ]]; then
        echo "security.inter.broker.protocol can not be set to ${SECURITY_INTER_BROKER_PROTOCOL}, as SSL is not enabled on this Kafka broker."
        exit 1
    fi
    if [[ ${SECURITY_INTER_BROKER_PROTOCOL} == *"SASL"* && ${KERBEROS_AUTH_ENABLED} != "true" ]]; then
        echo "security.inter.broker.protocol can not be set to ${SECURITY_INTER_BROKER_PROTOCOL}, as Kerberos is not enabled on this Kafka broker."
        exit 1
    fi


    if [[ ${SECURITY_INTER_BROKER_PROTOCOL} == *"SSL"* ]]; then
        LISTENERS="${LISTENERS}${SECURITY_INTER_BROKER_PROTOCOL}://${HOST}:${SSL_PORT},"
    else
        LISTENERS="${LISTENERS}${SECURITY_INTER_BROKER_PROTOCOL}://${HOST}:${PORT},"
    fi
fi
echo "LISTENERS=${LISTENERS}"

# Replace LISTENERS's placeholder
perl -pi -e "s#\#listeners={{LISTENERS}}#${LISTENERS}#" $CONF_DIR/kafka.properties

# Propoagating logger information to Kafka
export KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:$CONF_DIR/log4j.properties"

# Set LOG_DIR to pwd as this directory exists and hence the underlaying run-kafka-class.sh won't try to create a new directory inside the parcel
export LOG_DIR=`pwd`

# Set heap size
export KAFKA_HEAP_OPTS="-Xmx${BROKER_HEAP_SIZE}M"

# Set java opts
export KAFKA_JVM_PERFORMANCE_OPTS="${BROKER_JAVA_OPTS}"

# Set KAFKA_OPTS for security
if [[ ${KERBEROS_AUTH_ENABLED} == "true" ]]; then
    export KAFKA_OPTS="${KAFKA_OPTS} -Djava.security.auth.login.config=${CONF_DIR}/jaas.conf"

    if [[ ${AUTHENTICATE_ZOOKEEPER_CONNECTION} == "true" ]]; then
      export KAFKA_OPTS="${KAFKA_OPTS} -Dzookeeper.sasl.client.username=${ZK_PRINCIPAL_NAME}"
    fi
fi

# And finally run Kafka itself
exec $KAFKA_HOME/bin/kafka-server-start.sh $CONF_DIR/kafka.properties