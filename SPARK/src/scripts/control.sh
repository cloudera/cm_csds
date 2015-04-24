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

function get_default_fs {
  $HDFS_BIN --config $1 getconf -confKey fs.defaultFS 2>/dev/null
}

# replace $1 with $2 in file $3
function replace {
  perl -pi -e "s#${1}#${2}#g" $3
}

# prepare the spark-env.sh file specified in $1 for use.
function prepare_spark_env {
  local SPARK_ENV=$1
  replace "{{MASTER_IP}}" "$MASTER_IP" $SPARK_ENV
  replace "{{MASTER_PORT}}" "$MASTER_PORT" $SPARK_ENV
  replace "{{HADOOP_HOME}}" "$HADOOP_HOME" $SPARK_ENV
  replace "{{SPARK_HOME}}" "$SPARK_HOME" $SPARK_ENV
  replace "{{SPARK_EXTRA_LIB_PATH}}" "$SPARK_EXTRA_LIB_PATH" $SPARK_ENV
  replace "{{SPARK_JAR_HDFS_PATH}}" "$SPARK_JAR_HDFS_PATH" $SPARK_ENV
  replace "{{HIVE_HOME}}" "$CDH_HIVE_HOME" $SPARK_ENV
  replace "{{FLUME_HOME}}" "$CDH_FLUME_HOME" $SPARK_ENV
  replace "{{PARQUET_HOME}}" "$CDH_HADOOP_HOME/../parquet" $SPARK_ENV
  replace "{{AVRO_HOME}}" "$CDH_HADOOP_HOME/../avro" $SPARK_ENV
  replace "{{HADOOP_EXTRA_CLASSPATH}}" "$HADOOP_CLASSPATH" $SPARK_ENV
}

log "Detected CDH_VERSION of [$CDH_VERSION]"

DEFAULT_SPARK_HOME=/usr/lib/spark

# Set this to not source defaults
export BIGTOP_DEFAULTS_DIR=""

export SPARK_HOME=${SPARK_HOME:-$CDH_SPARK_HOME}
export HADOOP_HOME=${HADOOP_HOME:-$CDH_HADOOP_HOME}
export HADOOP_CONF_DIR=$CONF_DIR/hadoop-conf
export HDFS_BIN=$HADOOP_HOME/../../bin/hdfs

# If SPARK_HOME is not set, make it the default
export SPARK_HOME=${SPARK_HOME:-$DEFAULT_SPARK_HOME}

# CSD plugins may modify SPARK_LIBRARY_PATH to point to other needed native library paths.
# Stash that value in a separate variable since we use SPARK_LIBRARY_PATH to support Spark 0.9
# (from CDH 5.0).
SPARK_EXTRA_LIB_PATH="$SPARK_LIBRARY_PATH"

### Let's run everything with JVM runtime, instead of Scala
export SPARK_LAUNCH_WITH_SCALA=0
export SPARK_LIBRARY_PATH=${SPARK_HOME}/lib
export SCALA_LIBRARY_PATH=${SPARK_HOME}/lib

ENV_FILENAME="spark-env.sh"

if [ -n "$HADOOP_HOME" ]; then
  SPARK_LIBRARY_PATH=$SPARK_LIBRARY_PATH:${HADOOP_HOME}/lib/native
fi
if [ -n "$SPARK_EXTRA_LIB_PATH" ]; then
  SPARK_LIBRARY_PATH="$SPARK_LIBRARY_PATH:$SPARK_EXTRA_LIB_PATH"
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
    prepare_spark_env $SPARK_CONF_DIR/$ENV_FILENAME
    ARGS=("org.apache.spark.deploy.master.Master")
    ARGS+=("--ip $MASTER_IP")
    ;;

  (start_worker)
    log "Starting Spark worker using $MASTER_URL"
    prepare_spark_env $SPARK_CONF_DIR/$ENV_FILENAME
    MASTER_URL="spark://$MASTER_IP:$MASTER_PORT"
    ARGS=("org.apache.spark.deploy.worker.Worker")
    ARGS+=($MASTER_URL)
    ;;

  (start_history_server)
    log "Starting Spark History Server"
    prepare_spark_env $SPARK_CONF_DIR/$ENV_FILENAME
    ARGS=(
      "org.apache.spark.deploy.history.HistoryServer"
      $1
      $(get_default_fs $HADOOP_CONF_DIR)$2
    )
    ;;

  (client)
    log "Deploying client configuration"

    CLIENT_CONF_DIR=$CONF_DIR/spark-conf
    prepare_spark_env $CLIENT_CONF_DIR/$ENV_FILENAME

    # Move the Yarn configuration under the Spark config. Do not overwrite Spark's log4j config.
    HADOOP_CLIENT_CONF_DIR=$CLIENT_CONF_DIR/yarn-conf
    mkdir $HADOOP_CLIENT_CONF_DIR
    for i in $HADOOP_CONF_DIR/*; do
      if [ $(basename "$i") != log4j.properties ]; then
        mv $i $HADOOP_CLIENT_CONF_DIR
      fi
    done

    SPARK_DEFAULTS=$CLIENT_CONF_DIR/spark-defaults.conf
    echo "spark.master=spark://$MASTER_IP:$MASTER_PORT" >> $SPARK_DEFAULTS

    # SPARK 1.1 makes "file:" the default protocol for the location of event logs. So we need
    # to fix the configuration file to add the protocol.
    if grep -q 'spark.eventLog.dir' $SPARK_DEFAULTS; then
      DEFAULT_FS=$(get_default_fs $HADOOP_CLIENT_CONF_DIR)
      replace "(spark\\.eventLog\\.dir)=(.*)" "\\1=$DEFAULT_FS\\2" $SPARK_DEFAULTS
    fi

    # If a history server is configured, set its address in the default config file so that
    # the Yarn RM web ui links to the history server for Spark apps.
    HISTORY_PROPS=$CONF_DIR/history.properties
    HISTORY_HOST=
    if [ -f $HISTORY_PROPS ]; then
      for line in $(cat $HISTORY_PROPS)
      do
        readconf "$line"
        case $key in
          history.port)
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

    # Set the default library paths for drivers and executors.
    EXTRA_LIB_PATH="$HADOOP_HOME/lib/native"
    if [ -n "$SPARK_EXTRA_LIB_PATH" ]; then
      EXTRA_LIB_PATH="$EXTRA_LIB_PATH:$SPARK_EXTRA_LIB_PATH"
    fi
    for i in driver executor; do
      if ! grep -q "^spark\\.${i}\\.extraLibraryPath" $SPARK_DEFAULTS; then
        echo "spark.${i}.extraLibraryPath=$EXTRA_LIB_PATH" >> $SPARK_DEFAULTS
      fi
    done

    exit 0
    ;;

  (upload_jar)

    # The assembly jar does not exist in Spark for CDH4.
    if [ $CDH_VERSION -lt 5 ]; then
      log "Detected CDH [$CDH_VERSION]. Uploading Spark assembly jar skipped."
      exit 0
    fi

    log "Uploading Spark assembly jar to '$SPARK_JAR_HDFS_PATH' on CDH $CDH_VERSION cluster"

    if [ -d $SPARK_HOME/assembly/lib ]; then
      PATTERN="$SPARK_HOME/assembly/lib/spark-assembly*cdh*.jar"
    else
      PATTERN="$SPARK_HOME/lib/spark-assembly-*.jar"
    fi
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
    if $HDFS_BIN dfs -test -f "$SPARK_JAR_HDFS_PATH" ; then
      BAK=$SPARK_JAR_HDFS_PATH.$(date +%s)
      log "Backing up existing Spark jar as $BAK"
      $HDFS_BIN dfs -mv "$SPARK_JAR_HDFS_PATH" "$BAK"
    else
      # Create HDFS hierarchy
      $HDFS_BIN dfs -mkdir -p $(dirname "$SPARK_JAR_HDFS_PATH")
    fi

    $HDFS_BIN dfs -put "$SPARK_JAR_LOCAL_PATH" "$SPARK_JAR_HDFS_PATH"
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
