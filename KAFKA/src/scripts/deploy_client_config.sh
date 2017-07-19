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
echo "Host: `hostname`"
echo "Pwd: `pwd`"
echo "KAFKA_HOME: $KAFKA_HOME"
echo "CONF_DIR: $CONF_DIR"
echo "Zookeeper Quorum: $ZK_QUORUM"
echo "Zookeeper Chroot: $CHROOT"

echo "Deploying client configuration"

KAFKA_CONF_DIR="$CONF_DIR/kafka-conf"
KAFKA_CLIENT_CONF="$KAFKA_CONF_DIR/kafka-client.conf"
SENTRY_CONF_DIR="$CONF_DIR/sentry-conf"
SENTRY_CLIENT_CONF_DIR="$KAFKA_CONF_DIR/sentry-conf"
SENTRY_SITE_XML="sentry-site.xml"

# Generating Zookeeper quorum
QUORUM=$ZK_QUORUM
if [[ -n $CHROOT ]]; then
	QUORUM="${QUORUM}${CHROOT}"
fi
echo "Final Zookeeper Quorum is $QUORUM"
# Replace zookeeper.connect placeholder
perl -pi -e "s#\#zookeeper.connect={{QUORUM}}#zookeeper.connect=${QUORUM}#" $KAFKA_CLIENT_CONF

# If Sentry is configured, move Sentry configuration under Kafka config
if [[ -f $SENTRY_CONF_DIR/$SENTRY_SITE_XML ]]; then
  mkdir "$SENTRY_CLIENT_CONF_DIR"
  for i in "$SENTRY_CONF_DIR"/*; do
    mv $i "$SENTRY_CLIENT_CONF_DIR"
  done
  rm -rf "$SENTRY_CONF_DIR"
fi