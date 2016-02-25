#!/bin/bash
##
#
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

add_to_accumulo_site() {
  FILE=`find $CONF_DIR -name accumulo-site.xml`
  CONF_END="</configuration>"
  NEW_PROPERTY="<property><name>$1</name><value>$2</value></property>"
  TMP_FILE=$CONF_DIR/tmp-accumulo-site
  cat $FILE | sed "s#$CONF_END#$NEW_PROPERTY#g" > $TMP_FILE
  cp $TMP_FILE $FILE
  rm -f $TMP_FILE
  echo $CONF_END >> $FILE
}

set -x

# Source the common script to use acquire_kerberos_tgt
. $COMMON_SCRIPT

# Set env vars needed for Accumulo
export ACCUMULO_HOME=${CDH_ACCUMULO_HOME:-/usr/lib/accumulo}
export HADOOP_HOME_WARN_SUPPRESS=true
export HADOOP_HOME=$CDH_HADOOP_HOME
export HADOOP_PREFIX=$HADOOP_HOME
export HADOOP_CLIENT_HOME=$HADOOP_HOME/client-0.20
if [ $CDH_VERSION -gt 4 ]; then
  export HADOOP_CLIENT_HOME=$HADOOP_HOME/client
fi
if [ "$1" = "client" ]; then
  export HADOOP_CONF_DIR=/etc/hadoop/conf
else
  export HADOOP_CONF_DIR=$CONF_DIR/hadoop-conf
fi
export ACCUMULO_CONF_DIR=$CONF_DIR
export ZOOKEEPER_HOME=$CDH_ZOOKEEPER_HOME

# Set this because we don't want accumulo's config.sh script to create directories
export ACCUMULO_VERIFY_ONLY=true
export ACCUMULO_TEST=true

# Set GC and MONITOR because otherwise accumulo's config.sh will exit
export GC=unused
export MONITOR=unused

cp $CONF_DIR/aux/accumulo-metrics.xml $CONF_DIR/

# Add zk quorum to accumulo-site.xml
add_to_accumulo_site instance.zookeeper.host $ZK_QUORUM

# Add classpath to accumulo-site.xml
FULL_CLASSPATH="\$ACCUMULO_HOME/lib/[^.].*.jar"
FULL_CLASSPATH="$FULL_CLASSPATH,\$HADOOP_CONF_DIR"
FULL_CLASSPATH="$FULL_CLASSPATH,\$HADOOP_CLIENT_HOME/[^.](?!lf4j-log4j|uava|vro).*-[0-9a.]*.jar"
FULL_CLASSPATH="$FULL_CLASSPATH,\$HADOOP_CLIENT_HOME/slf4j-log4j12.jar"
FULL_CLASSPATH="$FULL_CLASSPATH,\$HADOOP_CLIENT_HOME/avro.jar"
# Needed for C5.5+ until HTrace has a non-incubating release.
# on C5.4 will add an unneeded extra jar to the classpath.
FULL_CLASSPATH="$FULL_CLASSPATH,\$HADOOP_CLIENT_HOME/htrace-core.jar"
# and on later versions with HTrace 4.
FULL_CLASSPATH="$FULL_CLASSPATH,\$HADOOP_CLIENT_HOME/htrace-core4.jar"
FULL_CLASSPATH="$FULL_CLASSPATH,\$HADOOP_CLIENT_HOME/[^.](?!ookeeper).*-[0-9.]*(?:-[^-]*)?-cdh.*.jar"
FULL_CLASSPATH="$FULL_CLASSPATH,\$ZOOKEEPER_HOME/zookeeper.*-[0-9].*.jar"

if [ "$ACCUMULO_CLASSPATH" != "" ]; then
  # Pre-pend any user specified directories
  FULL_CLASSPATH="$ACCUMULO_CLASSPATH,$FULL_CLASSPATH"
fi
add_to_accumulo_site general.classpaths $FULL_CLASSPATH

if [ "$accumulo_principal" != "" ]; then
  add_to_accumulo_site general.kerberos.keytab $CONF_DIR/accumulo16.keytab
fi

if [ -z $ACCUMULO_OTHER_OPTS ]; then
  export ACCUMULO_OTHER_OPTS=" -Xmx1g "
fi

  
# New for 1.6 - Add extra properties to logging configuration
if [ "$1" = "monitor" ]; then
  sed -i '/log4j\.appender\.RFA\.layout\.ConversionPattern/d' $CONF_DIR/log4j.properties
  cat $CONF_DIR/scripts/monitor_extra_log4j.properties >> $CONF_DIR/log4j.properties
  mv $CONF_DIR/log4j.properties $CONF_DIR/monitor_logger.properties
elif [ "$1" != "client" ]; then
  sed -i '/log4j\.appender\.RFA\.layout\.ConversionPattern/d' $CONF_DIR/log4j.properties
  cat $CONF_DIR/scripts/generic_extra_log4j.properties >> $CONF_DIR/log4j.properties
  mv $CONF_DIR/log4j.properties $CONF_DIR/generic_logger.properties
fi
# End of new work for 1.6


if [ "$1" = "master" ]; then
  $ACCUMULO_HOME/bin/accumulo org.apache.accumulo.master.state.SetGoalState NORMAL
elif [ "$1" = "client" ]; then
  CLIENT_CONF_DIR=$CONF_DIR/accumulo-conf
  perl -pi -e "s#{{accumulo_general_opts}}#$ACCUMULO_GENERAL_OPTS#g" $CLIENT_CONF_DIR/accumulo-env.sh
  perl -pi -e "s#{{accumulo_other_opts}}#$ACCUMULO_OTHER_OPTS#g" $CLIENT_CONF_DIR/accumulo-env.sh
  chmod 777 $CLIENT_CONF_DIR/*
  exit 0
elif [ "$1" = "init" ]; then
  echo $INSTANCE_NAME > script
  echo $INSTANCE_PASSWORD >> script
  echo $INSTANCE_PASSWORD >> script
  if [ "$accumulo_principal" != "" ]; then
    export SCM_KERBEROS_PRINCIPAL=$accumulo_principal
    acquire_kerberos_tgt accumulo16.keytab
  fi
  cat script | $ACCUMULO_HOME/bin/accumulo init
  exit $?
elif [ "$1" = "upgrade" ]; then
  echo "Upgrading Accumulo WALs from 1.4 to 1.6"
  exec $ACCUMULO_HOME/bin/accumulo org.apache.accumulo.tserver.log.LocalWALRecovery
fi

if [ "$1" = "admin" ]; then
  exec $ACCUMULO_HOME/bin/accumulo "$@"
else
  HOST=`hostname`
  if [ "$1" = "monitor" -a "$ACCUMULO_MONITOR_BIND_ALL" = "true" ]; then
    HOST="0.0.0.0"
  fi
  exec $ACCUMULO_HOME/bin/accumulo $1 --address $HOST
fi
