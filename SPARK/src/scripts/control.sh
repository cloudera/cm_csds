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

# Time marker for both stderr and stdout
date 1>&2

CMD=$1
MASTER_FILE=$CONF_DIR/$2
shift 2

function log {
  timestamp=$(date)
  echo "$timestamp: $1"       #stdout
  echo "$timestamp: $1" 1>&2; #stderr
}

# Reads a line in the format "$host:$key=$value", setting those variables.
function readconf {
  local conf
  IFS=':' read host conf <<< "$1"
  IFS='=' read key value <<< "$conf"
}

log "Detected CDH_VERSION of [$CDH_VERSION]"

DEFAULT_SPARK_HOME=/usr/lib/spark

export SPARK_HOME=${SPARK_HOME:-$CDH_SPARK_HOME}
export HADOOP_HOME=${HADOOP_HOME:-$CDH_HADOOP_HOME}

# If SPARK_HOME is not set, make it the default
export SPARK_HOME=${SPARK_HOME:-$DEFAULT_SPARK_HOME}

if [ -f $MASTER_FILE ]; then
  MASTER_IP=
  MASTER_PORT=
  for line in $(cat $MASTER_FILE)
  do
    readconf "$line"
    case $key in
     (server.port)
       MASTER_IP=$host
       MASTER_PORT=$value
     ;;
    esac
  done
  log "Found a master on $MASTER_IP listening on port $MASTER_PORT"
fi

# We want to use a local conf dir
export SPARK_CONF_DIR=$CONF_DIR/config
if [ ! -d "$SPARK_CONF_DIR" ]; then
  mkdir $SPARK_CONF_DIR
fi

# Copy the log4j directory to the config directory if it exists.
if [ -f $CONF_DIR/log4j.properties ]; then
  cp $CONF_DIR/log4j.properties $SPARK_CONF_DIR/.
fi

# Set JAVA_OPTS for the daemons
# sets preference to IPV4
export SPARK_DAEMON_JAVA_OPTS="$SPARK_DAEMON_JAVA_OPTS -Djava.net.preferIPv4Stack=true"

ARGS=()
case $CMD in

  (start_master)
    log "Starting Spark master on $MASTER_IP and port $MASTER_PORT"
    ARGS=("org.apache.spark.deploy.master.Master")
    ARGS+=("--ip $MASTER_IP")
    ;;

  (start_worker)
    MASTER_URL="spark://$MASTER_IP:$MASTER_PORT"
    log "Starting Spark worker using $MASTER_URL"
    ARGS=("org.apache.spark.deploy.worker.Worker")
    ARGS+=($MASTER_URL)
    ;;

  (start_history_server)
    log "Starting Spark History Server"
    ARGS=("org.apache.spark.deploy.history.HistoryServer")
    ARGS+=($@)
    ;;

  (client)
    log "Deploying client configuration"

    CLIENT_CONF_DIR=$CONF_DIR/spark-conf
    ENV_FILENAME="spark-env.sh"

    perl -pi -e "s#{{MASTER_IP}}#$MASTER_IP#g" $CLIENT_CONF_DIR/$ENV_FILENAME
    perl -pi -e "s#{{MASTER_PORT}}#$MASTER_PORT#g" $CLIENT_CONF_DIR/$ENV_FILENAME
    perl -pi -e "s#{{HADOOP_HOME}}#$HADOOP_HOME#g" $CLIENT_CONF_DIR/$ENV_FILENAME
    perl -pi -e "s#{{SPARK_HOME}}#$SPARK_HOME#g" $CLIENT_CONF_DIR/$ENV_FILENAME
    perl -pi -e "s#{{SPARK_JAR_HDFS_PATH}}#$SPARK_JAR_HDFS_PATH#g" $CLIENT_CONF_DIR/$ENV_FILENAME

    SPARK_DEFAULTS=$CLIENT_CONF_DIR/spark-defaults.conf
    echo "spark.master=spark://$MASTER_IP:$MASTER_PORT" >> $SPARK_DEFAULTS

    # If a history server is configured, set its address in the default config file so that
    # the Yarn RM web ui links to the history server for Spark apps.
    HISTORY_PROPS=$CONF_DIR/history.properties
    HISTORY_HOST=
    if [ -f $HISTORY_PROPS ]; then
      for line in $(cat $HISTORY_PROPS)
      do
        readconf "$line"
        case $key in
         (history.port)
           HISTORY_HOST=$host
           HISTORY_PORT=$value
         ;;
        esac
      done
      if [ -n "$HISTORY_HOST" ]; then
        echo "spark.yarn.historyServer.address=http://$HISTORY_HOST:$HISTORY_PORT" >> \
          $CONF_DIR/spark-conf/spark-defaults.conf
      fi
    fi

    exit 0
    ;;

  (upload_jar)

    # The assembly jar does not exist in Spark for CDH4.
    if [ $CDH_VERSION -lt 5 ]; then
      log "Detected CDH [$CDH_VERSION]. Uploading Spark assembly jar skipped."
      exit 0
    fi

    log "Uploading Spark assembly jar to '$SPARK_JAR_HDFS_PATH' on CDH $CDH_VERSION cluster"

    PATTERN="$SPARK_HOME/assembly/lib/spark-assembly*cdh*.jar"
    for jar in $PATTERN; do
      if [ -f "$jar" ] ; then
        # If there are multiple, use the first one
        SPARK_JAR_LOCAL_PATH="$jar"
        break
      fi
    done

    if [ -z $SPARK_JAR_LOCAL_PATH ] ; then
      log "Cannot find the assembly on local filesystem: $PATTERN"
      exit 1
    fi

    # Does it already exist on HDFS?
    if hdfs --config $CONF_DIR/hadoop-conf dfs -test -f "$SPARK_JAR_HDFS_PATH" ; then
      BAK=$SPARK_JAR_HDFS_PATH.$(date +%s)
      log "Backing up existing Spark jar as $BAK"
      hdfs --config $CONF_DIR/hadoop-conf dfs -mv "$SPARK_JAR_HDFS_PATH" "$BAK"
    else
      # Create HDFS hierarchy
      hdfs --config $CONF_DIR/hadoop-conf dfs -mkdir -p $(dirname "$SPARK_JAR_HDFS_PATH")
    fi

    hdfs --config $CONF_DIR/hadoop-conf dfs -put "$SPARK_JAR_LOCAL_PATH" "$SPARK_JAR_HDFS_PATH"
    exit $?
    ;;

  (*)
    log "Don't understand [$CMD]"
    ;;

esac
ARGS+=($ADDITIONAL_ARGS)

cmd="$SPARK_HOME/bin/spark-class ${ARGS[@]}"
echo "Running [$cmd]"
exec $cmd
