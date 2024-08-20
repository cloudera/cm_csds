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
. ${COMMON_SCRIPT}

set -ex
export CDP_ROOT=$(cd $(m_readlink "$CDH_HADOOP_HOME/../..") && pwd)
CDH_ENV_KINIT=${CDH_ENV_KINIT:-/usr/bin/kinit}


start_zeppelin_server() {
  export ZEPPELIN_INTERPRETER_CONFIG_DIR=${ZEPPELIN_INTERPRETER_CONFIG_DIR:7}
  if [ ! -f "${ZEPPELIN_INTERPRETER_CONFIG_DIR}/interpreter.json" ]; then
    log "interpreter.json not found. Copying default interpreter.json"
    mkdir -p ${ZEPPELIN_INTERPRETER_CONFIG_DIR}
    cp aux/interpreter.json ${ZEPPELIN_INTERPRETER_CONFIG_DIR}
  fi

  configure_livy_interpreter
  configure_livy_interpreter 3

  log "Starting Zeppelin server (CDP $CDH_VERSION)"

  export USER=$(whoami)
  export ZEPPELIN_IDENT_STRING=$(whoami)
  export SPARK_CONF_DIR=
  export HIVE_CONF_DIR=
  export ZEPPELIN_HOME="$CDP_ROOT/lib/zeppelin"
  export ZEPPELIN_CONF_DIR="$CONF_DIR/zeppelin-conf"

  export HADOOP_CONF_DIR="$CONF_DIR/hadoop-conf"
  perl -pi -e "s#\{\{HADOOP_CONF_DIR}}#${HADOOP_CONF_DIR}#g" ${ZEPPELIN_CONF_DIR}/zeppelin-env.sh


  # required to start zeppelin
  cd ${ZEPPELIN_HOME}
  . "bin/common.sh"
  . "bin/functions.sh"

  HOSTNAME=$(hostname)
  ZEPPELIN_NAME="Zeppelin"
  ZEPPELIN_MAIN=org.apache.zeppelin.server.ZeppelinServer
  JAVA_OPTS+=" -Dzeppelin.log.file=${ZEPPELIN_LOGFILE}"

  # Uncomment below to override additional jvm arguments provided by cloudera-config.sh:
  ##  JAVA8_ADDITIONAL_JVM_ARGS="my jvm argument for JAVA8"
  JAVA11_ADDITIONAL_JVM_ARGS="--add-modules jdk.unsupported \
  --add-opens java.base/java.nio=ALL-UNNAMED \
  --add-opens java.base/sun.nio.ch=ALL-UNNAMED \
  --add-opens java.base/java.lang=ALL-UNNAMED \
  --add-opens java.base/jdk.internal.ref=ALL-UNNAMED \
  --add-opens java.base/java.lang.reflect=ALL-UNNAMED \
  --add-opens java.base/java.util=ALL-UNNAMED \
  --add-opens java.base/java.util.concurrent=ALL-UNNAMED \
  --add-exports java.base/jdk.internal.misc=ALL-UNNAMED \
  --add-exports java.security.jgss/sun.security.krb5=ALL-UNNAMED \
  --add-exports java.base/sun.net.dns=ALL-UNNAMED \
  --add-exports java.base/sun.net.util=ALL-UNNAMED"
  JAVA17_ADDITIONAL_JVM_ARGS="${JAVA11_ADDITIONAL_JVM_ARGS} \
  --add-opens java.base/jdk.internal.util.random=ALL-UNNAMED"

  # function from cloudera-config.sh provides ADDITIONAL_JVM_ARGS based on java version
  set_additional_jvm_args_based_on_java_version

  get_generic_java_opts
  JAVA_OPTS="${JAVA_OPTS} ${GENERIC_JAVA_OPTS} ${ADDITIONAL_JVM_ARGS}"

  # construct classpath
  if [[ -n "${HADOOP_CONF_DIR}" ]] && [[ -d "${HADOOP_CONF_DIR}" ]]; then
    ZEPPELIN_CLASSPATH+=":${HADOOP_CONF_DIR}"
  fi

  addJarInDir "${ZEPPELIN_HOME}"
  addJarInDir "${ZEPPELIN_HOME}/lib"
  addJarInDir "${ZEPPELIN_HOME}/lib/interpreter"
  addJarInDir "${ZEPPELIN_HOME}/interpreter"

  CLASSPATH+=":${ZEPPELIN_CLASSPATH}"

  SHIRO_CONTENT=""
  IS_KNOX_CONFIGURED="false"

  # build shiro.ini start
  if [[ -n "$ZEPPELIN_PRINCIPAL"  ]]; then

    KEYTAB_FILE="${CONF_DIR}/zeppelin.keytab"
    perl -pi -e "s#\{\{KEYTAB_FILE}}#${KEYTAB_FILE}#g" ${ZEPPELIN_CONF_DIR}/zeppelin-site.xml

    if [[ -n "$SPNEGO_PRINCIPAL"  ]]; then
      if [[ -n "$KNOX_SERVICE" && "$KNOX_SERVICE" != "none" ]];then

        dd if=/dev/urandom of=${CONF_DIR}/http_secret bs=1024 count=1
        chmod 444 ${CONF_DIR}/http_secret

        export DOMAIN=".$(echo ${SPNEGO_PRINCIPAL} | cut -d'/' -f2 | cut -d'@' -f1 | cut -d'.' -f2-)"
        IS_KNOX_CONFIGURED="true"

        shiro_knox_main_block=$(echo "${shiro_knox_main_block}" | sed "s#{{KEYTAB_FILE}}#${KEYTAB_FILE}#g")
        shiro_knox_main_block=$(echo "${shiro_knox_main_block}" | sed "s#{{SPNEGO_PRINCIPAL}}#${SPNEGO_PRINCIPAL}#g")
        shiro_knox_main_block=$(echo "${shiro_knox_main_block}" | sed "s#{{DOMAIN}}#${DOMAIN}#g")
        shiro_knox_main_block=$(echo "${shiro_knox_main_block}" | sed "s#{{CONF_DIR}}#${CONF_DIR}#g")

        SHIRO_CONTENT+="[main]\n"
        SHIRO_CONTENT+="${shiro_knox_main_block}\n"

      fi
    fi
  fi

  if [[ "$IS_KNOX_CONFIGURED" == "false" ]]; then
    SHIRO_CONTENT="[users]\n"
    SHIRO_CONTENT+="${shiro_user_block}\n"
    SHIRO_CONTENT+="[main]\n"
    SHIRO_CONTENT+="${shiro_main_block}\n"
  fi

  SHIRO_CONTENT+="${shiro_main_session_block}\n"
  SHIRO_CONTENT+="[roles]\n"
  SHIRO_CONTENT+="${shiro_roles_block}\n"

  shiro_urls_block=$(echo "${shiro_urls_block}" | sed "s#{{zeppelin_admin_group}}#${zeppelin_admin_group}#g")
  SHIRO_CONTENT+="[urls]\n"
  SHIRO_CONTENT+="${shiro_urls_block}\n"

  echo -e "$SHIRO_CONTENT" > "$ZEPPELIN_CONF_DIR/shiro.ini"
  # build shiro.ini end

  exec $ZEPPELIN_RUNNER $JAVA_OPTS -cp $ZEPPELIN_CLASSPATH_OVERRIDES:$CLASSPATH $ZEPPELIN_MAIN
}

configure_livy_interpreter() {
  export LIVY_URI=
  export LIVY3_URI=
  local SERVER_LIST="$CONF_DIR/livy$1-conf/livy-server.properties"
  local SERVER_HOST=
  local SERVER_PORT=
  local SCHEME="http"
  for line in $(cat "$SERVER_LIST")
  do
    readconf "$line"
    case $key in
      (livy.server.port)
        SERVER_HOST="$host"
        SERVER_PORT="$value"
        ;;
      (livy.tls.enabled)
        if [ "$value" = "true" ]; then
          SCHEME="https"
        fi
        ;;
    esac
  done
  if [ -n "$SERVER_HOST" ]; then
    if [ -n "$1" ]; then
      LIVY3_URI="$SCHEME://$SERVER_HOST:$SERVER_PORT"
    else
      LIVY_URI="$SCHEME://$SERVER_HOST:$SERVER_PORT"
    fi
  fi

  if [ "$LIVY_URI" ]; then
    log "Found Livy URI $LIVY_URI. Configuring interpreter.json"
    PYTHON_COMMAND_INVOKER=${PYTHON_COMMAND_INVOKER:-python}
    $(${PYTHON_COMMAND_INVOKER} ${CONF_DIR}/scripts/update_interpreter.py)
  fi

  if [ "$LIVY3_URI" ]; then
    log "Found Livy3 URI $LIVY3_URI. Configuring interpreter.json"
    PYTHON_COMMAND_INVOKER=${PYTHON_COMMAND_INVOKER:-python}
    $(${PYTHON_COMMAND_INVOKER} ${CONF_DIR}/scripts/update_interpreter.py)
  fi
}

gen_client_conf() {
  log "Configuring Zeppelin server (CDP $CDH_VERSION)"

  if [[ "${zeppelin_notebook_storage}" == 'org.apache.zeppelin.notebook.repo.FileSystemNotebookRepo' ]]
  then
    if [[ -n "$ZEPPELIN_PRINCIPAL"  ]]; then
      $CDH_ENV_KINIT -kt "${CONF_DIR}/zeppelin.keytab" "${ZEPPELIN_PRINCIPAL}"
    fi

    log "Copying default notebook shipped with Zeppelin to HDFS/S3 file system"
    "$HDFS_BIN" dfs -mkdir -p "${zeppelin_notebook_dir}"
    "$HDFS_BIN" dfs -put $CDP_ROOT/lib/zeppelin/notebook/* "${zeppelin_notebook_dir}" && echo "All notebooks copied." || echo "Notebook(s) already exists, did not attempt to overwrite."

  else
    log "Copying default notebook shipped with Zeppelin to local file system"
    cp -r $CDP_ROOT/lib/zeppelin/notebook ${zeppelin_notebook_dir}
  fi
}

case $1 in
  (start_zeppelin_server)
    start_zeppelin_server
    ;;

  (gen_client_conf)
    gen_client_conf
    ;;

  (*)
    log "Unknown command [$1]"
    exit 1
    ;;
esac
