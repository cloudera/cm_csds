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

#
# Set of utility functions shared across different Spark CSDs.
#

set -ex

function log {
  timestamp=$(date)
  echo "$timestamp: $1"       #stdout
  echo "$timestamp: $1" 1>&2; #stderr
}

# Time marker for both stderr and stdout
log "Running Spark CSD control script..."
log "Detected CDH_VERSION of [$CDH_VERSION]"

# Set this to not source defaults
export BIGTOP_DEFAULTS_DIR=""

export HADOOP_HOME=${HADOOP_HOME:-$(readlink -m "$CDH_HADOOP_HOME")}
export HDFS_BIN=$HADOOP_HOME/../../bin/hdfs

HAS_HDFS_CONFIG=1
if [ -d "$CONF_DIR/yarn-conf" ]; then
  HADOOP_CONF_DIR="$CONF_DIR/yarn-conf"
elif [ -d "$CONF_DIR/hadoop-conf" ]; then
  HADOOP_CONF_DIR="$CONF_DIR/hadoop-conf"
else
  # No YARN nor HDFS, so create an empty directory just so that
  # the commands we run can work. On top of that, when reading
  # fs.defaultFS with an empty config, it contains a leading slash
  # which makes the final URL of the event log directory invalid,
  # so we override that with a default value.
  mkdir "$CONF_DIR/empty-hadoop-conf"
  HADOOP_CONF_DIR="$CONF_DIR/empty-hadoop-conf"
  HAS_HDFS_CONFIG=0
fi
export HADOOP_CONF_DIR
export USE_EMPTY_DEFAULT_FS

# If SPARK_HOME is not set, make it the default
DEFAULT_SPARK_HOME=/usr/lib/spark
SPARK_HOME=$(readlink -m ${SPARK_HOME:-$CDH_SPARK_HOME})
export SPARK_HOME=${SPARK_HOME:-$DEFAULT_SPARK_HOME}

# We want to use a local conf dir
export SPARK_CONF_DIR="$CONF_DIR/spark-conf"
if [ ! -d "$SPARK_CONF_DIR" ]; then
  mkdir "$SPARK_CONF_DIR"
fi

# Fixing CHD-42916
if [ -f $CONF_DIR/log4j.properties ]; then
  cp "$CONF_DIR/log4j.properties" "$SPARK_CONF_DIR"
fi

# Variables used when generating configs.
export SPARK_ENV="$SPARK_CONF_DIR/spark-env.sh"
export SPARK_DEFAULTS="$SPARK_CONF_DIR/spark-defaults.conf"

# Set JAVA_OPTS for the daemons
# sets preference to IPV4
export SPARK_DAEMON_JAVA_OPTS="$SPARK_DAEMON_JAVA_OPTS -Djava.net.preferIPv4Stack=true"

# Make sure PARCELS_ROOT is in the format we expect, canonicalized and without a trailing slash.
export PARCELS_ROOT=$(readlink -m "$PARCELS_ROOT")

# Reads a line in the format "$host:$key=$value", setting those variables.
function readconf {
  local conf
  IFS=':' read host conf <<< "$1"
  IFS='=' read key value <<< "$conf"
}

function get_hadoop_conf {
  local conf="$1"
  local key="$2"
  if [ $HAS_HDFS_CONFIG == 1 ]; then
    "$HDFS_BIN" --config "$conf" getconf -confKey "$key"
  else
    echo ""
  fi
}

function get_default_fs {
  get_hadoop_conf "$1" "fs.defaultFS"
}


# replace $1 with $2 in file $3
function replace {
  perl -pi -e "s#${1}#${2}#g" $3
}

# Read a configuration value from a Spark config file.
function read_spark_conf {
  local key="$1"
  local file="$2"
  echo $(grep "^$key=" "$file" | tail -n 1 | sed "s/^$key=\(.*\)/\\1/")
}

# Replaces a configuration in the Spark config with a new value; keeps just
# one entry for the configuration (in case the value is defined multiple times
# because of safety valves).
function replace_spark_conf {
  local key="$1"
  local value="$2"
  local file="$3"
  local temp="$file.tmp"
  grep -v "^$key=" "$file" > "$temp"
  echo "$key=$value" >> "$temp"
  mv "$temp" "$file"
}

# Prepend a given protocol string to the URL if it doesn't have a protocol.
function prepend_protocol {
  local url="$1"
  local proto="$2"
  if [[ "$url" =~ [:alnum:]*:.* ]]; then
    echo "$url"
  else
    echo "$proto$url"
  fi
}

# Blacklists certain jars from Spark's classpath to avoid a few issues.
# - avro-tools: not needed by Spark and re-packages a bunch of things.
# - jersey, any version but 1.9: CDH has other versions of jersey and things break if multiple are
#   in the classpath.
# - jackson, any version but 1.8 (used by hadoop) and 2.2.3 (used by Spark).
function is_blacklisted {
  local JAR=$(basename "$1")

  if [[ "$JAR" =~ ^avro-tools* ]]; then
    return 0
  elif [[ "$JAR" =~ ^jersey.*-1\.[^9].*\.jar ]]; then
    return 0
  elif [[ "$JAR" =~ ^jackson.* ]] && ! [[ "$JAR" =~ ^jackson.*-(1\.8|2\.2\.3).*\.jar ]]; then
    return 0
  fi
  return 1
}

function add_to_classpath {
  local CLASSPATH_FILE="$1"
  local CLASSPATH="$2"

  # Break the classpath into individual entries
  IFS=: read -a CLASSPATH_ENTRIES <<< "$CLASSPATH"

  # Expand each component of the classpath, resolve symlinks, and add
  # entries to the classpath file, ignoring duplicates.
  for pattern in "${CLASSPATH_ENTRIES[@]}"; do
    for entry in $pattern; do
      entry=$(readlink -m "$entry")
      name=$(basename $entry)
      if [ -f "$entry" ] && ! is_blacklisted "$entry" && ! grep -q "/$name\$" "$CLASSPATH_FILE"
      then
        echo "$entry" >> "$CLASSPATH_FILE"
      fi
    done
  done
}

# prepare the spark-env.sh file specified in $1 for use.
# $2 should contain the path to the Spark jar in HDFS. This is for backwards compatibility
# so that users of CDH 5.1 and earlier have a way to reference it.
function prepare_spark_env {
  replace "{{HADOOP_HOME}}" "$HADOOP_HOME" $SPARK_ENV
  replace "{{SPARK_HOME}}" "$SPARK_HOME" $SPARK_ENV
  replace "{{SPARK_EXTRA_LIB_PATH}}" "$SPARK_LIBRARY_PATH" $SPARK_ENV
  replace "{{SPARK_JAR_HDFS_PATH}}" "$SPARK_JAR" $SPARK_ENV
  replace "{{MASTER_PORT}}" "$MASTER_PORT" $SPARK_ENV
  replace "{{PYTHON_PATH}}" "$PYTHON_PATH" $SPARK_ENV
  replace "{{CDH_PYTHON}}" "$CDH_PYTHON" $SPARK_ENV

  local HADOOP_CONF_DIR_NAME=$(basename "$HADOOP_CONF_DIR")
  replace "{{HADOOP_CONF_DIR_NAME}}" "$HADOOP_CONF_DIR_NAME" $SPARK_ENV

  # Create a classpath.txt file with all the entries that should be in Spark's classpath.
  # The classpath is expanded so that we can de-duplicate entries, to avoid having the JVM
  # opening the same jar file multiple times.
  local CLASSPATH_FILE="$(dirname $SPARK_ENV)/classpath.txt"
  local CLASSPATH_FILE_TMP="${CLASSPATH_FILE}.tmp"

  touch "$CLASSPATH_FILE_TMP"
  add_to_classpath "$CLASSPATH_FILE_TMP" "$HADOOP_HOME/client/*.jar"

  local HADOOP_CP="$($HADOOP_HOME/bin/hadoop --config $HADOOP_CONF_DIR classpath)"
  add_to_classpath "$CLASSPATH_FILE_TMP" "$HADOOP_CP"

  # CDH-29066. Some versions of CDH don't define CDH_AVRO_HOME nor CDH_PARQUET_HOME. But the CM
  # agent does define a default value for CDH_PARQUET_HOME which does not work with parcels. So
  # detect those cases here and do the right thing.
  if [ -z "$CDH_AVRO_HOME" ]; then
    CDH_AVRO_HOME="$CDH_HADOOP_HOME/../avro"
  fi
  if [ -n "$PARCELS_ROOT" ]; then
    if ! [[ $CDH_PARQUET_HOME == $PARCELS_ROOT* ]]; then
      CDH_PARQUET_HOME="$CDH_HADOOP_HOME/../parquet"
    fi
  fi

  add_to_classpath "$CLASSPATH_FILE_TMP" "$CDH_HIVE_HOME/lib/*.jar"
  add_to_classpath "$CLASSPATH_FILE_TMP" "$CDH_FLUME_HOME/lib/*.jar"
  add_to_classpath "$CLASSPATH_FILE_TMP" "$CDH_PARQUET_HOME/lib/*.jar"
  add_to_classpath "$CLASSPATH_FILE_TMP" "$CDH_AVRO_HOME/*.jar"
  if [ -n "HADOOP_CLASSPATH" ]; then
    add_to_classpath "$CLASSPATH_FILE_TMP" "$HADOOP_CLASSPATH"
  fi

  if [ -n "CDH_SPARK_CLASSPATH" ]; then
    add_to_classpath "$CLASSPATH_FILE_TMP" "$CDH_SPARK_CLASSPATH"
  fi

  cat "$CLASSPATH_FILE_TMP" | sort | uniq > "$CLASSPATH_FILE"
  rm -f "$CLASSPATH_FILE_TMP"
}

function find_local_spark_jar {
  # CDH-28715: use the version-less symlink if available to work around a bug in CM's
  # stale configuration detection. This should allow a newer Spark installation to run
  # with a config that has not been updated, although any other updated configs will
  # be missed.
  local SPARK_JAR_LOCAL_PATH=
  if [ -f "$SPARK_HOME/lib/spark-assembly.jar" ]; then
    echo "$SPARK_HOME/lib/spark-assembly.jar"
  elif [ -f "$SPARK_HOME/assembly/lib/spark-assembly.jar" ]; then
    echo "$SPARK_HOME/assembly/lib/spark-assembly.jar"
  else
    PATTERN="$SPARK_HOME/assembly/lib/spark-assembly*cdh*.jar"
    for jar in $PATTERN; do
      if [ -f "$jar" ] ; then
        # If there are multiple, use the first one
        SPARK_JAR_LOCAL_PATH="$jar"
        break
      fi
    done
    if [ -z "$SPARK_JAR_LOCAL_PATH" ]; then
      log "Cannot find the Spark assembly on local filesystem: $PATTERN"
      return 1
    fi
    echo "$SPARK_JAR_LOCAL_PATH"
  fi
}

# Check whether the given config key ($1) exists in the given conf file ($2).
function has_config {
  local key="$1"
  local file="$2"
  grep -q "^$key=" "$file"
}

function run_spark_class {
  local ARGS=($@)
  ARGS+=($ADDITIONAL_ARGS)
  prepare_spark_env
  export SPARK_DAEMON_JAVA_OPTS="$CSD_JAVA_OPTS $SPARK_DAEMON_JAVA_OPTS"
  export SPARK_JAVA_OPTS="$CSD_JAVA_OPTS $SPARK_JAVA_OPTS"
  cmd="$SPARK_HOME/bin/spark-class ${ARGS[@]}"
  echo "Running [$cmd]"
  exec $cmd
}

function start_history_server {
  log "Starting Spark History Server"
  local CONF_FILE="$SPARK_CONF_DIR/spark-history-server.conf"
  local DEFAULT_FS=$(get_default_fs $HADOOP_CONF_DIR)
  local LOG_DIR=$(prepend_protocol "$HISTORY_LOG_DIR" "$DEFAULT_FS")
  if [ -f "$CONF_FILE" ]; then
    echo "spark.history.fs.logDirectory=$LOG_DIR" >> "$CONF_FILE"

    ARGS=(
      "org.apache.spark.deploy.history.HistoryServer"
      "--properties-file"
      "$CONF_FILE"
    )
  else
    ARGS=(
      "org.apache.spark.deploy.history.HistoryServer"
      -d
      "$LOG_DIR"
    )
  fi

  if [ "$SPARK_PRINCIPAL" != "" ]; then
    KRB_OPTS="-Dspark.history.kerberos.enabled=true"
    KRB_OPTS="$KRB_OPTS -Dspark.history.kerberos.principal=$SPARK_PRINCIPAL"
    KRB_OPTS="$KRB_OPTS -Dspark.history.kerberos.keytab=spark_on_yarn.keytab"
    export SPARK_DAEMON_JAVA_OPTS="$KRB_OPTS $SPARK_DAEMON_JAVA_OPTS"
  fi
  run_spark_class "${ARGS[@]}"
}

function deploy_client_config {
  log "Deploying client configuration"

  prepare_spark_env
  if [ -n "$PYTHON_PATH" ]; then
    echo "spark.executorEnv.PYTHONPATH=$PYTHON_PATH" >> $SPARK_DEFAULTS
  fi

  # Move the Yarn configuration under the Spark config. Do not overwrite Spark's log4j config.
  HADOOP_CONF_NAME=$(basename "$HADOOP_CONF_DIR")
  HADOOP_CLIENT_CONF_DIR="$SPARK_CONF_DIR/$HADOOP_CONF_NAME"
  TARGET_HADOOP_CONF_DIR="$DEST_PATH/$HADOOP_CONF_NAME"

  mkdir "$HADOOP_CLIENT_CONF_DIR"
  for i in "$HADOOP_CONF_DIR"/*; do
    if [ $(basename "$i") != log4j.properties ]; then
      mv $i "$HADOOP_CLIENT_CONF_DIR"

      # CDH-28425. Because of OPSAPS-25695, we need to fix the YARN config ourselves.
      target="$HADOOP_CLIENT_CONF_DIR/$(basename $i)"
      replace "{{CDH_MR2_HOME}}" "$CDH_MR2_HOME" "$target"
      replace "{{HADOOP_CLASSPATH}}" "$HADOOP_CLASSPATH" "$target"
      replace "{{JAVA_LIBRARY_PATH}}" "" "$target"
      replace "{{CMF_CONF_DIR}}" "$TARGET_HADOOP_CONF_DIR" "$target"
    fi
  done

  DEFAULT_FS=$(get_default_fs "$HADOOP_CLIENT_CONF_DIR")

  # SPARK 1.1 makes "file:" the default protocol for the location of event logs. So we need
  # to fix the configuration file to add the protocol. But if the user has specified a path
  # with a protocol, don't overwrite it.
  key="spark.eventLog.dir"
  value=$(read_spark_conf "$key" "$SPARK_DEFAULTS")
  if [ -n "$value" ]; then
    value=$(prepend_protocol "$value" "$DEFAULT_FS")
    replace_spark_conf "$key" "$value" "$SPARK_DEFAULTS"
  fi

  # If a history server is configured, set its address in the default config file so that
  # the Yarn RM web ui links to the history server for Spark apps.
  HISTORY_PROPS="$SPARK_CONF_DIR/history.properties"
  HISTORY_HOST=
  if [ -f "$HISTORY_PROPS" ]; then
    for line in $(cat "$HISTORY_PROPS")
    do
      readconf "$line"
      case $key in
       (spark.history.ui.port)
         HISTORY_HOST="$host"
         HISTORY_PORT="$value"
       ;;
      esac
    done
    if [ -n "$HISTORY_HOST" ]; then
      echo "spark.yarn.historyServer.address=http://$HISTORY_HOST:$HISTORY_PORT" >> \
        "$SPARK_DEFAULTS"
    fi
    rm "$HISTORY_PROPS"
  fi

  if [ $CDH_VERSION -ge 5 ]; then
    # If no Spark jar is defined, look for the location of the jar on the local filesystem,
    # which we assume will be the same across the cluster.
    key="spark.yarn.jar"
    value=$(read_spark_conf "$key" "$SPARK_DEFAULTS")
    if [ -n "$value" ]; then
      value=$(prepend_protocol "$value" "$DEFAULT_FS")
    else
      value="local:$(find_local_spark_jar)"
    fi
    replace_spark_conf "$key" "$value" "$SPARK_DEFAULTS"
  fi

  # Set the default library paths for drivers and executors.
  EXTRA_LIB_PATH="$HADOOP_HOME/lib/native"
  if [ -n "$SPARK_LIBRARY_PATH" ]; then
    EXTRA_LIB_PATH="$EXTRA_LIB_PATH:$SPARK_LIBRARY_PATH"
  fi
  for i in driver executor yarn.am; do
    key="spark.${i}.extraLibraryPath"
    value=$(read_spark_conf "$key" "$SPARK_DEFAULTS")
    if [ -n "$value" ]; then
      value="$value:$EXTRA_LIB_PATH"
    else
      value="$EXTRA_LIB_PATH"
    fi
    replace_spark_conf "$key" "$value" "$SPARK_DEFAULTS"
  done

  # If using parcels, write extra configuration that tells Spark to replace the parcel
  # path with references to the NM's environment instead, so that users can have different
  # paths on each node.
  if [ -n "$PARCELS_ROOT" ]; then
    echo "spark.yarn.config.gatewayPath=$PARCELS_ROOT" >> "$SPARK_DEFAULTS"
    echo "spark.yarn.config.replacementPath={{HADOOP_COMMON_HOME}}/../../.." >> "$SPARK_DEFAULTS"
  fi

  if [ -n "$CDH_PYTHON" ]; then
    echo "spark.yarn.appMasterEnv.PYSPARK_PYTHON=$CDH_PYTHON" >> "$SPARK_DEFAULTS"
    echo "spark.yarn.appMasterEnv.PYSPARK_DRIVER_PYTHON=$CDH_PYTHON" >> "$SPARK_DEFAULTS"
  fi

  # Modify the YARN configuration to use the topology script from Spark's config directory.
  # Also need to manually fix the permissions so that the script is executable.
  # If the config doesn't exist (e.g. for standalone, which depends on HDFS and not YARN),
  # we need to add the "|| true" hack to avoid an error in the caller (because of set -e).
  OLD_TOPOLOGY_SCRIPT=$(get_hadoop_conf "$HADOOP_CLIENT_CONF_DIR" "net.topology.script.file.name" || true)
  if [ -n "$OLD_TOPOLOGY_SCRIPT" ]; then
    SCRIPT_NAME=$(basename "$OLD_TOPOLOGY_SCRIPT")
    NEW_TOPOLOGY_SCRIPT="$TARGET_HADOOP_CONF_DIR/$SCRIPT_NAME"
    CORE_SITE="$HADOOP_CLIENT_CONF_DIR/core-site.xml"
    chmod 755 "$HADOOP_CLIENT_CONF_DIR/$SCRIPT_NAME"
    sed "s,$OLD_TOPOLOGY_SCRIPT,$NEW_TOPOLOGY_SCRIPT," "$CORE_SITE" > "$CORE_SITE.tmp"
    mv "$CORE_SITE.tmp" "$CORE_SITE"
  fi

  # These values cannot be declared in the descriptor, since the CSD framework will
  # treat them as config references and fail. So add them here unless they've already
  # been set by the user in the safety valve.
  #
  # Furthermore, because only a few versions of Spark support this feature, check whether
  # the "shell.log.level" property has been set in the logging configuration before adding
  # the new ones.
  LOG_CONFIG="$SPARK_CONF_DIR/log4j.properties"
  if has_config "shell.log.level" "$LOG_CONFIG"; then
    SHELL_CLASSES=("org.apache.spark.repl.Main"
      "org.apache.spark.api.python.PythonGatewayServer")
    for class in "${SHELL_CLASSES[@]}"; do
      key="log4j.logger.$class"
      if ! has_config "$key" "$LOG_CONFIG"; then
        echo "$key=\${shell.log.level}" >> "$LOG_CONFIG"
      fi
    done
  fi
}

function upload_jar {
  # The assembly jar does not exist in Spark for CDH4.
  if [ $CDH_VERSION -lt 5 ]; then
    log "Detected CDH [$CDH_VERSION]. Uploading Spark assembly jar skipped."
    exit 0
  fi

  if [ -z "$SPARK_JAR" ]; then
    log "Spark jar configuration is empty, skipping upload."
    exit 0
  fi

  log "Uploading Spark assembly jar to '$SPARK_JAR' on CDH $CDH_VERSION cluster"

  if [ -n "$SPARK_PRINCIPAL" ]; then
    # Source the common script to use acquire_kerberos_tgt
    . $COMMON_SCRIPT
    export SCM_KERBEROS_PRINCIPAL="$SPARK_PRINCIPAL"
    acquire_kerberos_tgt spark_on_yarn.keytab
  fi

  SPARK_JAR_LOCAL_PATH=$(find_local_spark_jar)

  # Does it already exist on HDFS?
  if $HDFS_BIN dfs -test -f "$SPARK_JAR" ; then
    BAK="$SPARK_JAR.$(date +%s)"
    log "Backing up existing Spark jar as $BAK"
    "$HDFS_BIN" dfs -mv "$SPARK_JAR" "$BAK"
  else
    # Create HDFS hierarchy
    "$HDFS_BIN" dfs -mkdir -p $(dirname "$SPARK_JAR")
  fi

  "$HDFS_BIN" dfs -put "$SPARK_JAR_LOCAL_PATH" "$SPARK_JAR"
  exit $?
}
