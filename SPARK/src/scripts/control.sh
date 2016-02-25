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
##

. $(cd $(dirname $0) && pwd)/common.sh

MASTER_FILE="$CONF_DIR/$MASTER_FILE"

### Let's run everything with JVM runtime, instead of Scala
export SPARK_LAUNCH_WITH_SCALA=0
export SPARK_LIBRARY_PATH=${SPARK_HOME}/lib
export SCALA_LIBRARY_PATH=${SPARK_HOME}/lib

if [ -n "$HADOOP_HOME" ]; then
  SPARK_LIBRARY_PATH=$SPARK_LIBRARY_PATH:${HADOOP_HOME}/lib/native
fi
export SPARK_LIBRARY_PATH

if [ -f $MASTER_FILE ]; then
  MASTER_IP=
  MASTER_PORT=
  for line in $(cat $MASTER_FILE)
  do
    readconf "$line"
    case $key in
      server.address)
        if [ -n "$value" ]; then
          MASTER_IP=$value
        fi
        ;;
      server.port)
        if [ -z "$MASTER_IP" ]; then
          MASTER_IP=$host
        fi
        MASTER_PORT=$value
        ;;
    esac
  done
  log "Found a master on $MASTER_IP listening on port $MASTER_PORT"
fi

case $1 in

  (start_master)
    log "Starting Spark master on $MASTER_IP and port $MASTER_PORT"
    ARGS=(
      "org.apache.spark.deploy.master.Master"
      "--ip"
      $MASTER_IP
    )

    prepare_spark_env $SPARK_CONF_DIR/$ENV_FILENAME
    run_spark_class "${ARGS[@]}"
    ;;

  (start_worker)
    log "Starting Spark worker using $MASTER_URL"
    MASTER_URL="spark://$MASTER_IP:$MASTER_PORT"
    ARGS=(
      "org.apache.spark.deploy.worker.Worker"
      $MASTER_URL
    )
    run_spark_class "${ARGS[@]}"
    ;;

  (start_history_server)
    start_history_server
    ;;

  (client)
    log "Deploying client configuration"
    deploy_client_config
    echo "spark.master=spark://$MASTER_IP:$MASTER_PORT" >> $SPARK_DEFAULTS
    ;;

  (upload_jar)
    upload_jar
    ;;

  (*)
    log "Don't understand [$1]"
    exit 1
    ;;

esac
