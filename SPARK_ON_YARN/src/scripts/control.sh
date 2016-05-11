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

case $1 in
  (start_history_server)
    start_history_server
    ;;

  (client)
    deploy_client_config
    # The default deploy mode. Passed as an argument to the script. Prepend it with "yarn-"
    # to build the default master configuration, but try not to overwrite user configs.
    if ! grep -q 'spark.master' $SPARK_DEFAULTS; then
      echo "spark.master=yarn-$DEPLOY_MODE" >> $SPARK_DEFAULTS
    fi
    ;;

  (upload_jar)
    upload_jar
    ;;

  (*)
    log "Don't understand [$1]"
    exit 1
    ;;
esac
