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

set -x

# Time marker for both stderr and stdout
date; date 1>&2

CMD=$1
shift

DEFAULT_KMS_HOME=/usr/lib/hadoop-kms

# Use CDH_KMS_HOME if available
export KMS_HOME=${KMS_HOME:-$CDH_KMS_HOME}
# If KMS_HOME is still not set, use the default value
export KMS_HOME=${KMS_HOME:-$DEFAULT_KMS_HOME}

# Set KMS config dir to conf dir
export KMS_CONFIG=${CONF_DIR}

# We want verbose startup logs
export KMS_SILENT=false

KMS_RUN=$CONF_DIR/run/
export KMS_TEMP=$KMS_RUN

# Need to set the libexec dir to find kms-config.sh
export HADOOP_HOME=${CDH_HADOOP_HOME}
export HADOOP_LIBEXEC_DIR=${HADOOP_HOME}/libexec

# Needed to find catalina.sh
export KMS_CATALINA_HOME=$TOMCAT_HOME

export CATALINA_TMPDIR=$PWD/temp
# Create temp directory for Catalina
mkdir -p $CATALINA_TMPDIR

# Choose between the non-SSL and SSL tomcat configs
TOMCAT_CONFIG_FOLDER=tomcat-conf.http
if [ "x$SSL_ENABLED"  == "xtrue" ]; then
    TOMCAT_CONFIG_FOLDER=tomcat-conf.https
fi

# Package settings for tomcat deployment
DEPLOY_SCRIPT_BASE=/usr/lib/hadoop-kms/
TOMCAT_CONF_BASE=/etc/hadoop-kms/

# Rejigger the above if we're using parcels
if [ "$CDH_KMS_HOME" != "$DEFAULT_KMS_HOME" ]; then
    TOMCAT_CONF_BASE=$CDH_KMS_HOME/../../etc/hadoop-kms/
    DEPLOY_SCRIPT_BASE=$CDH_KMS_HOME
fi

# Construct the actual TOMCAT_CONF from the base and folder
TOMCAT_CONF=$TOMCAT_CONF_BASE/$TOMCAT_CONFIG_FOLDER

export CATALINA_BASE="$KMS_STAGING_DIR/tomcat-deployment"

# Set up the number of threads and heap size
export $KMS_MAX_THREADS
export CATALINA_OPTS="-Xmx${KMS_HEAP_SIZE}"

# Deploy KMS tomcat app.
env TOMCAT_CONF=${TOMCAT_CONF} TOMCAT_DEPLOYMENT=${CATALINA_BASE} KMS_HOME=${KMS_HOME} \
    bash ${DEPLOY_SCRIPT_BASE}/tomcat-deployment.sh

# Print out all the env vars we've set
echo "KMS_HOME is ${KMS_HOME}"
echo "KMS_LOG is ${KMS_LOG}"
echo "KMS_CONFIG is ${KMS_CONFIG}"
echo "KMS_MAX_THREADS is ${KMS_MAX_THREADS}"
echo "KMS_HEAP_SIZE is ${KMS_HEAP_SIZE}"
echo "TOMCAT_CONF is ${TOMCAT_CONF}"
echo "CATALINA_BASE is ${CATALINA_BASE}"
echo "SSL_ENABLED is ${SSL_ENABLED}"
echo "KMS_SSL_KEYSTORE_FILE is ${KMS_SSL_KEYSTORE_FILE}"

# replace {{CONF_DIR}} template in kms-site.xml
perl -pi -e "s#{{CONF_DIR}}#${CONF_DIR}#" ${CONF_DIR}/kms-site.xml

case $CMD in
    (start)
        cmd="${KMS_HOME}/sbin/kms.sh run"
        exec ${cmd}
        ;;
    (*)
        echo "Unknown command ${CMD}"
        exit 1
        ;;
esac
