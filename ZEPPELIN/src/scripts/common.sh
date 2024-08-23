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

[ -z $IN_BATS ] && set -x

# Source Generic cloudera utility functions
. $COMMON_SCRIPT

# simple wrapper around readlink to work with BATS, and also b/c
# readlink -m doesn't work on macos.
function m_readlink {
  if [ -n $IN_BATS ]; then
    echo $1
  else
    readlink -m $1
  fi
}

function log {
  timestamp=$(date)
  # stdout messes with BATS, so leave it out
  [ -z $IN_BATS ] && echo "$timestamp: $1"       #stdout
  echo "$timestamp: $1" 1>&2; #stderr
}

# Time marker for both stderr and stdout
log "Running Spark CSD control script..."
log "Detected CDH_VERSION of [$CDH_VERSION]"

# Set this to not source defaults
export BIGTOP_DEFAULTS_DIR=""

export HADOOP_HOME=${HADOOP_HOME:-$(m_readlink "$CDH_HADOOP_HOME")}
export HDFS_BIN=$HADOOP_HOME/../../bin/hdfs
export HADOOP_CONF_DIR="$CONF_DIR/yarn-conf"

HBASE_CONF_DIR="$CONF_DIR/hbase-conf"

# If SPARK_HOME is not set, make it the default
DEFAULT_SPARK_HOME=/usr/lib/spark
SPARK_HOME=$(m_readlink "${SPARK_HOME:-$CDH_SPARK_HOME}")
export SPARK_HOME=${SPARK_HOME:-$DEFAULT_SPARK_HOME}

# We want to use a local conf dir
export SPARK_CONF_DIR="$CONF_DIR/spark-conf"
if [ ! -d "$SPARK_CONF_DIR" ]; then
  mkdir "$SPARK_CONF_DIR"
fi

# Variables used when generating configs.
export SPARK_ENV="$SPARK_CONF_DIR/spark-env.sh"
export SPARK_DEFAULTS="$SPARK_CONF_DIR/spark-defaults.conf"

# Set JAVA_OPTS for the daemons
# sets preference to IPV4
export SPARK_DAEMON_JAVA_OPTS="$SPARK_DAEMON_JAVA_OPTS -Djava.net.preferIPv4Stack=true"

# Make sure PARCELS_ROOT is in the format we expect, canonicalized and without a trailing slash.
export PARCELS_ROOT=$(m_readlink "$PARCELS_ROOT")

# Reads a line in the format "$host:$key=$value", setting those variables.
function readconf {
  local conf
  IFS=':' read host conf <<< "$1"
  IFS='=' read key value <<< "$conf"
}

function get_hadoop_conf {
  local conf="$1"
  local key="$2"
  "$HDFS_BIN" --config "$conf" getconf -confKey "$key"
}

function get_default_fs {
  get_hadoop_conf "$1" "fs.defaultFS"
}

# replace $1 with $2 in file $3
function replace {
  perl -pi -e "s#${1}#${2}#g" $3
}

# Read a value from a properties file.
function read_property {
  local key="$1"
  local file="$2"
  echo $(grep "^$key=" "$file" | tail -n 1 | sed "s/^$key=\(.*\)/\\1/")
}

# Replaces a configuration in the Spark config with a new value; keeps just
# one entry for the configuration (in case the value is defined multiple times
# because of safety valves). If the new value is empty, the entry is removed from the config.
function replace_spark_conf {
  local key="$1"
  local value="$2"
  local file="$3"
  local temp="$file.tmp"
  touch "$temp"
  chown --reference="$file" "$temp"
  chmod --reference="$file" "$temp"
  grep -v "^$key=" "$file" >> "$temp"
  if [ -n "$value" ]; then
    echo "$key=$value" >> "$temp"
  fi
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

# Blacklists certain jars from being added by optional Spark dependencies. The list here is mostly
# based on what HBase adds to the classpath, and avoids adding conflicting versions of libraries
# that Spark needs. Also avoids adding duplicate jars to the classpath since that makes the JVM open
# the same file multiple times.
function is_blacklisted {
  local JAR=$(basename "$1")
  if [[ -f "$SPARK_HOME/$JAR" ]]; then
    return 0
  elif [[ "$JAR" =~ ^jetty.* ]]; then
    return 0
  elif [[ "$JAR" =~ ^jersey.* ]]; then
    return 0
  elif [[ "$JAR" =~ ^jackson.* ]]; then
    return 0
  elif [[ "$JAR" =~ ^jackson.* ]]; then
    return 0
  elif [[ "$JAR" =~ .*slf4j.* ]]; then
    return 0
  elif [[ "$JAR" =~ .*servlet.* ]]; then
    return 0
  elif [[ "$JAR" =~ .*-tests.jar ]]; then
    return 0
  elif [[ "$JAR" =~ ^junit-.* ]]; then
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
      entry=$(m_readlink "$entry")
      name=$(basename "$entry")
      if [ -f "$entry" ] && ! is_blacklisted "$entry" && ! grep -q "/$name\$" "$CLASSPATH_FILE"
      then
        echo "$entry" >> "$CLASSPATH_FILE"
      fi
    done
  done
}

# prepare the spark-env.sh file for use.
function prepare_spark_env {
  replace "\{\{HADOOP_HOME}}" "$HADOOP_HOME" $SPARK_ENV
  replace "\{\{SPARK_HOME}}" "$SPARK_HOME" $SPARK_ENV
  replace "\{\{SPARK_EXTRA_LIB_PATH}}" "$SPARK_LIBRARY_PATH" $SPARK_ENV
  replace "\{\{PYTHON_PATH}}" "$PYTHON_PATH" ""$SPARK_ENV""
  replace "\{\{CDH_PYTHON}}" "$CDH_PYTHON" $SPARK_ENV

  local HADOOP_CONF_DIR_NAME=$(basename "$HADOOP_CONF_DIR")
  replace "\{\{HADOOP_CONF_DIR_NAME}}" "$HADOOP_CONF_DIR_NAME" $SPARK_ENV
}

# create a classpath.txt file in the client config dir with the jars needed by external
# dependencies (such as HBase or parcel plugins).
function prepare_external_classpath {
  local CLASSPATH_FILE="$(dirname $SPARK_ENV)/classpath.txt"
  local CLASSPATH_FILE_TMP="${CLASSPATH_FILE}.tmp"

  touch "$CLASSPATH_FILE_TMP"
  add_to_classpath "$CLASSPATH_FILE_TMP" "$HADOOP_HOME/client/*.jar"

  # If there's an HBase configuration directory, add the classpath for HBase's mapreduce and spark
  # integration(s) after the Hadoop one.
  if [ -d "$HBASE_CONF_DIR" ]; then
    local HBASE_CP="$(hbase --config $HBASE_CONF_DIR mapredcp)"
    add_to_classpath "$CLASSPATH_FILE_TMP" "$HBASE_CP"
    # If HBASE_HOME is not set, make it the default
    if [ ! -d "${HBASE_HOME}" ]; then
      local DEFAULT_HBASE_HOME=/usr/lib/hbase
      HBASE_HOME="${CDH_HBASE_HOME}"
      HBASE_HOME=${HBASE_HOME:-$DEFAULT_HBASE_HOME}
    fi
    if [ -f "${HBASE_HOME}/hbase-spark.jar" ]; then
      add_to_classpath "$CLASSPATH_FILE_TMP" "${HBASE_HOME}/hbase-spark.jar"
    fi
  fi

  if [ -n "$HADOOP_CLASSPATH" ]; then
    add_to_classpath "$CLASSPATH_FILE_TMP" "$HADOOP_CLASSPATH"
  else
    # $HADOOP_CLASSPATH is parcel only; for packages, we need to at least get
    # the gpl extras, if available.  See CDH-70058
    if [ -e "/usr/lib/hadoop/lib/hadoop-lzo.jar" ]; then
      add_to_classpath "$CLASSPATH_FILE_TMP" "/usr/lib/hadoop/lib/hadoop-lzo.jar"
    fi
    if [ -d "/usr/lib/spark-netlib/lib" ];then
      add_to_classpath "$CLASSPATH_FILE_TMP" "/usr/lib/spark-netlib/lib/*.jar"
    fi
  fi

  if [ -n "$CDH_SPARK_CLASSPATH" ]; then
    add_to_classpath "$CLASSPATH_FILE_TMP" "$CDH_SPARK_CLASSPATH"
  fi

  if [ -s "$CLASSPATH_FILE_TMP" ]; then
    cat "$CLASSPATH_FILE_TMP" | sort | uniq > "$CLASSPATH_FILE"
  fi
  rm -f "$CLASSPATH_FILE_TMP"
}

function copy_client_config {
  local source_dir="$1"
  local target_dir="$2"
  local dest_dir="$3"

  # this fails weirdly if $source_dir doesn't exist or is empty
  for i in "$source_dir"/*; do
    if [ $(basename "$i") != log4j.properties ]; then
      mv $i "$target_dir"
      # CDH-28425. Because of OPSAPS-25695, we need to fix the YARN config ourselves.
      target="$target_dir/$(basename $i)"
      replace "\{\{CDH_MR2_HOME}}" "$CDH_MR2_HOME" "$target"
      replace "\{\{HADOOP_CLASSPATH}}" "" "$target"
      replace "\{\{JAVA_LIBRARY_PATH}}" "" "$target"
      replace "\{\{CMF_CONF_DIR}}" "$dest_dir" "$target"
    fi
  done
}

# Appends an item ($2) to a comma-separated list ($1).
function add_to_list {
  local list="$1"
  local item="$2"
  if [ -n "$list" ]; then
    list="$list,$item"
  else
    list="$item"
  fi
  echo "$list"
}

function run_spark_class {
  local ARGS=($@)
  ARGS+=($ADDITIONAL_ARGS)
  get_generic_java_opts
  prepare_spark_env
  export SPARK_DAEMON_JAVA_OPTS="$CSD_JAVA_OPTS $GENERIC_JAVA_OPTS $SPARK_DAEMON_JAVA_OPTS"
  export SPARK_JAVA_OPTS="$CSD_JAVA_OPTS $GENERIC_JAVA_OPTS $SPARK_JAVA_OPTS"
  cmd="$SPARK_HOME/bin/spark-class ${ARGS[@]}"
  echo "Running [$cmd]"
  exec $cmd
}

function start_history_server {
  log "Starting Spark History Server"
  local CONF_FILE="$SPARK_CONF_DIR/spark-history-server.conf"
  local DEFAULT_FS=$(get_default_fs $HADOOP_CONF_DIR)
  local LOG_DIR=$(prepend_protocol "$HISTORY_LOG_DIR" "$DEFAULT_FS")

  # Make a defensive copy of the config file; when startup fails, CM will retry the same
  # process again, so we want to append configs to the original config file, not to the
  # update version.
  if [ ! -f "$CONF_FILE.orig" ]; then
    cp -p "$CONF_FILE" "$CONF_FILE.orig"
  fi
  cp -p "$CONF_FILE.orig" "$CONF_FILE"

  echo "spark.history.fs.logDirectory=$LOG_DIR" >> "$CONF_FILE"
  if [ "$SPARK_PRINCIPAL" != "" ]; then
    echo "spark.history.kerberos.enabled=true" >> "$CONF_FILE"
    echo "spark.history.kerberos.principal=$SPARK_PRINCIPAL" >> "$CONF_FILE"
    echo "spark.history.kerberos.keytab=spark_on_yarn.keytab" >> "$CONF_FILE"
  fi

  local FILTERS_KEY="spark.ui.filters"
  local FILTERS=$(read_property "$FILTERS_KEY" "$CONF_FILE")

  if [ "$YARN_PROXY_REDIRECT" = "true" ]; then
    FILTERS=$(add_to_list "$FILTERS" "org.apache.spark.deploy.yarn.YarnProxyRedirectFilter")
  fi

  if [ "$ENABLE_SPNEGO" = "true" ] && [ -n "$SPNEGO_PRINCIPAL" ]; then
    local AUTH_FILTER="org.apache.hadoop.security.authentication.server.AuthenticationFilter"
    FILTERS=$(add_to_list "$FILTERS" "$AUTH_FILTER")

    local FILTER_CONF_KEY="spark.$AUTH_FILTER.param"
    echo "$FILTER_CONF_KEY.type=kerberos" >> "$CONF_FILE"
    echo "$FILTER_CONF_KEY.kerberos.principal=$SPNEGO_PRINCIPAL" >> "$CONF_FILE"
    echo "$FILTER_CONF_KEY.kerberos.keytab=spark_on_yarn.keytab" >> "$CONF_FILE"

    # This config may contain new lines and backslashes, so it needs to be handled in a special way.
    # To preserve those characters in Java properties files, replace them with the respective
    # unicode escape sequence.
    local AUTH_TO_LOCAL=$(get_hadoop_conf "$HADOOP_CONF_DIR" "hadoop.security.auth_to_local" |
      sed 's,\\,\\u005C,g' |
      awk '{printf "%s\\u000A", $0}')
    echo "$FILTER_CONF_KEY.kerberos.name.rules=$AUTH_TO_LOCAL" >> "$CONF_FILE"

    # Also enable ACLs in the History Server, otherwise auth is not very useful.
    echo "spark.history.ui.acls.enable=true" >> "$CONF_FILE"
  fi

  if [ -n "$FILTERS" ]; then
    replace_spark_conf "$FILTERS_KEY" "$FILTERS" "$CONF_FILE"
  fi

  # Disable logging while checking sensitive data.
  set +x
  if [ -n "$KEYSTORE_PASSWORD" ]; then
    # This value cannot be declared in the descriptor, since the CSD framework will
    # treat it as config reference and fail.
    echo 'spark.ssl.historyServer.keyStorePassword=${env:KEYSTORE_PASSWORD}' >> "$CONF_FILE"
  fi
  set -x

  # If local storage is not configured, remove the entry from the properties file, since the
  # mere presence of the configuration enables the feature.
  if [ "$ENABLE_LOCAL_STORAGE" != "true" ]; then
    replace_spark_conf "spark.history.store.path" "" "$CONF_FILE"
  fi

  ARGS=(
    "org.apache.spark.deploy.history.HistoryServer"
    "--properties-file"
    "$CONF_FILE"
  )
  run_spark_class "${ARGS[@]}"
}

# Check whether the given config key ($1) exists in the given conf file ($2).
function has_config {
  local key="$1"
  local file="$2"
  grep -q "^$key=" "$file"
}

# Set a configuration key ($1) to a value ($2) in the file ($3) only if it hasn't already been
# set by the user.
function set_config {
  local key="$1"
  local value="$2"
  local file="$3"
  if ! has_config "$key" "$file"; then
    echo "$key=$value" >> "$file"
  fi
}

function deploy_client_config {
  log "Deploying client configuration"

  prepare_spark_env
  prepare_external_classpath

  set_config 'spark.master' 'yarn' "$SPARK_DEFAULTS"
  set_config 'spark.submit.deployMode' "$DEPLOY_MODE" "$SPARK_DEFAULTS"

  if [ -n "$PYTHON_PATH" ]; then
    echo "spark.executorEnv.PYTHONPATH=$PYTHON_PATH" >> $SPARK_DEFAULTS
  fi

  # Move the Yarn configuration under the Spark config. Do not overwrite Spark's log4j config.
  HADOOP_CONF_NAME=$(basename "$HADOOP_CONF_DIR")
  HADOOP_CLIENT_CONF_DIR="$SPARK_CONF_DIR/$HADOOP_CONF_NAME"
  TARGET_HADOOP_CONF_DIR="$DEST_PATH/$HADOOP_CONF_NAME"

  mkdir "$HADOOP_CLIENT_CONF_DIR"
  copy_client_config "$HADOOP_CONF_DIR" "$HADOOP_CLIENT_CONF_DIR" "$TARGET_HADOOP_CONF_DIR"

  # If there's an HBase configuration directory, copy its files to the Spark config dir.
  if [ -d "$HBASE_CONF_DIR" ]; then
    copy_client_config "$HBASE_CONF_DIR" "$HADOOP_CLIENT_CONF_DIR" "$TARGET_HADOOP_CONF_DIR"
  fi

  DEFAULT_FS=$(get_default_fs "$HADOOP_CLIENT_CONF_DIR")

  # SPARK 1.1 makes "file:" the default protocol for the location of event logs. So we need
  # to fix the configuration file to add the protocol. But if the user has specified a path
  # with a protocol, don't overwrite it.
  key="spark.eventLog.dir"
  value=$(read_property "$key" "$SPARK_DEFAULTS")
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

  # Set the location of the YARN jars to point to the install directory on all nodes.
  local jars="local:$SPARK_HOME/jars/*,local:$SPARK_HOME/hive/*"
  replace_spark_conf "spark.yarn.jars" "$jars" "$SPARK_DEFAULTS"

  # Set the default library paths for drivers and executors.
  EXTRA_LIB_PATH="$HADOOP_HOME/lib/native"
  if [ -n "$SPARK_LIBRARY_PATH" ]; then
    EXTRA_LIB_PATH="$EXTRA_LIB_PATH:$SPARK_LIBRARY_PATH"
  fi
  for i in driver executor yarn.am; do
    key="spark.${i}.extraLibraryPath"
    value=$(read_property "$key" "$SPARK_DEFAULTS")
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

  # These values cannot be declared in the descriptor, since the CSD framework will
  # treat them as config references and fail. So add them here unless they've already
  # been set by the user in the safety valve.
  LOG_CONFIG="$SPARK_CONF_DIR/log4j.properties"
  SHELL_CLASSES=("org.apache.spark.repl.Main"
    "org.apache.spark.api.python.PythonGatewayServer")
  for class in "${SHELL_CLASSES[@]}"; do
    key="log4j.logger.$class"
    if ! has_config "$key" "$LOG_CONFIG"; then
      echo "$key=\${shell.log.level}" >> "$LOG_CONFIG"
    fi
  done

  # Allow SHS to be used when UI is disabled.
  local key="spark.yarn.historyServer.allowTracking"
  if ! has_config "$key" "$SPARK_DEFAULTS"; then
    echo "$key=true" >> "$SPARK_DEFAULTS"
  fi

  # Force single-threaded BLAS (CDH-58082).
  local env_vars="MKL_NUM_THREADS OPENBLAS_NUM_THREADS"
  local env_confs="spark.yarn.appMasterEnv spark.executorEnv"
  for e in $env_vars; do
    for conf in $env_confs; do
      if ! has_config "$conf.$e" "$SPARK_DEFAULTS"; then
        echo "$conf.$e=1" >> "$SPARK_DEFAULTS"
      fi
    done
  done

  # Add the Navigator listeners to the client config.
  local LINEAGE_ENABLED=$(read_property spark.lineage.enabled "$SPARK_DEFAULTS")
  if [ "$LINEAGE_ENABLED" = "true" ]; then
    local SC_LISTENERS_KEY="spark.extraListeners"
    local SQL_LISTENERS_KEY="spark.sql.queryExecutionListeners"
    local LINEAGE_PKG="com.cloudera.spark.lineage"

    local LISTENERS=$(read_property "$SC_LISTENERS_KEY" "$SPARK_DEFAULTS")
    LISTENERS=$(add_to_list "$LISTENERS" "$LINEAGE_PKG.NavigatorAppListener")
    replace_spark_conf "$SC_LISTENERS_KEY" "$LISTENERS" "$SPARK_DEFAULTS"

    local LISTENERS=$(read_property "$SQL_LISTENERS_KEY" "$SPARK_DEFAULTS")
    LISTENERS=$(add_to_list "$LISTENERS" "$LINEAGE_PKG.NavigatorQueryListener")
    replace_spark_conf "$SQL_LISTENERS_KEY" "$LISTENERS" "$SPARK_DEFAULTS"
  fi
}

function clean_history_cache {
  local STORAGE_DIR="$1"
  log "Cleaning history server cache in $STORAGE_DIR"

  if [ -d "$STORAGE_DIR" ]; then
    rm -rf "$STORAGE_DIR"/*
  fi
}
