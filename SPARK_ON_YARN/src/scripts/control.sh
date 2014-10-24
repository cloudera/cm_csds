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
  hdfs --config $1 getconf -confKey fs.defaultFS 2>/dev/null
}

log "Detected CDH_VERSION of [$CDH_VERSION]"

DEFAULT_SPARK_HOME=/usr/lib/spark

# Set this to not source defaults
export BIGTOP_DEFAULTS_DIR=""

export SPARK_HOME=${SPARK_HOME:-$CDH_SPARK_HOME}
export HADOOP_HOME=${HADOOP_HOME:-$CDH_HADOOP_HOME}
export HADOOP_CONF_DIR=$CONF_DIR/yarn-conf

# If SPARK_HOME is not set, make it the default
export SPARK_HOME=${SPARK_HOME:-$DEFAULT_SPARK_HOME}

### Let's run everything with JVM runtime, instead of Scala
export SPARK_LAUNCH_WITH_SCALA=0
export SPARK_LIBRARY_PATH=${SPARK_HOME}/lib
export SCALA_LIBRARY_PATH=${SPARK_HOME}/lib

if [ -n "$HADOOP_HOME" ]; then
  export SPARK_LIBRARY_PATH=$SPARK_LIBRARY_PATH:${HADOOP_HOME}/lib/native
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

  (start_history_server)
    log "Starting Spark History Server"
    ARGS=(
      "org.apache.spark.deploy.history.HistoryServer"
      $1
      $(get_default_fs $HADOOP_CONF_DIR)$2
    )
    if [ "$SPARK_PRINCIPAL" != "" ]; then
      KRB_OPTS="-Dspark.history.kerberos.enabled=true"
      KRB_OPTS="$KRB_OPTS -Dspark.history.kerberos.principal=$SPARK_PRINCIPAL"
      KRB_OPTS="$KRB_OPTS -Dspark.history.kerberos.keytab=spark_on_yarn.keytab"
      export SPARK_DAEMON_JAVA_OPTS="$KRB_OPTS $SPARK_DAEMON_JAVA_OPTS"
    fi
    ;;

  (client)
    log "Deploying client configuration"

    CLIENT_CONF_DIR=$CONF_DIR/spark-conf
    ENV_FILENAME="spark-env.sh"

    perl -pi -e "s#{{HADOOP_HOME}}#$HADOOP_HOME#g" $CLIENT_CONF_DIR/$ENV_FILENAME
    perl -pi -e "s#{{SPARK_HOME}}#$SPARK_HOME#g" $CLIENT_CONF_DIR/$ENV_FILENAME
    perl -pi -e "s#{{SPARK_JAR_HDFS_PATH}}#$SPARK_JAR_HDFS_PATH#g" $CLIENT_CONF_DIR/$ENV_FILENAME

    SPARK_DEFAULTS=$CLIENT_CONF_DIR/spark-defaults.conf

    # SPARK 1.1 makes "file:" the default protocol for the location of event logs. So we need
    # to fix the configuration file to add the protocol.
    if grep -q 'spark.eventLog.dir' $SPARK_DEFAULTS; then
      DEFAULT_FS=$(get_default_fs /etc/hadoop/conf)
      perl -pi -e "s#(spark\\.eventLog\\.dir)=(.*)#\\1=$DEFAULT_FS\\2#" $SPARK_DEFAULTS
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

    log "Uploading Spark assembly jar to '$SPARK_JAR_HDFS_PATH' on CDH $CDH_VERSION cluster"

    if [ "$SPARK_PRINCIPAL" != "" ]; then
      # Source the common script to use acquire_kerberos_tgt
      . $COMMON_SCRIPT
      export SCM_KERBEROS_PRINCIPAL=$SPARK_PRINCIPAL
      acquire_kerberos_tgt spark_on_yarn.keytab
    fi

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
    if hdfs dfs -test -f "$SPARK_JAR_HDFS_PATH" ; then
      BAK=$SPARK_JAR_HDFS_PATH.$(date +%s)
      log "Backing up existing Spark jar as $BAK"
      hdfs dfs -mv "$SPARK_JAR_HDFS_PATH" "$BAK"
    else
      # Create HDFS hierarchy
      hdfs dfs -mkdir -p $(dirname "$SPARK_JAR_HDFS_PATH")
    fi

    hdfs dfs -put "$SPARK_JAR_LOCAL_PATH" "$SPARK_JAR_HDFS_PATH"
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
