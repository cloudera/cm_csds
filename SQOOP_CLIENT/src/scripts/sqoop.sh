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

# Configuration variables that can be exported by connector parcels
#
# CSD_SQOOP_CONNECTOR_PATH
#   List of paths to all connectors. Separated by ":".
#
# CSD_SQOOP_EXTRA_CLASSPATH
#   Extra CLASSPATH entry that should be available to Sqoop.
#

# Time marker for both stderr and stdout
date 1>&2

# Running command
CMD=$1

# Printout with timestamp
function log {
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$timestamp: $1"
}

CLIENT_CONF_DIR=$CONF_DIR/sqoop-conf
MANAGERS_D_DIR=$CLIENT_CONF_DIR/managers.d

log "Loaded CSD_SQOOP_CONNECTOR_PATH: $CSD_SQOOP_CONNECTOR_PATH"

case $CMD in

  (client)
    log "Creating managers.d directory at $MANAGERS_D_DIR"
    if [ ! -d $MANAGERS_D_DIR ]; then
      mkdir $MANAGERS_D_DIR
    fi

    # Extra generated classpath
    EXTRA_CLASSPATH=""

    HOMES=(${CSD_SQOOP_CONNECTOR_PATH//:/ })
    for HOME_DIR in ${HOMES[@]}; do
      log "Found connector in $HOME_DIR"

      # Configuration file managers.d
      for FILE_PATH in $HOME_DIR/managers.d/*; do
        if [ -f $FILE_PATH ]; then
           FILENAME=$(basename "$FILE_PATH")
           cp $FILE_PATH $MANAGERS_D_DIR/.
           perl -pi -e "s#{{ROOT}}#$HOME_DIR#g" $MANAGERS_D_DIR/$FILENAME
        fi
      done

      # Extra libraries
      if [ -d $HOME_DIR/lib/ ]; then
        for file in `ls $HOME_DIR/lib/*`; do
          log "Found library: $file"
          EXTRA_CLASSPATH=$EXTRA_CLASSPATH:$file
        done
      fi
    done

    # The parcels can also export CSD_SQOOP_EXTRA_CLASSPATH to put arbitrary items
    # to final classpath.
    EXTRA_CLASSPATH="$EXTRA_CLASSPATH:$CSD_SQOOP_EXTRA_CLASSPATH"

    # Append our generated CLASSPATH at the end to ensure that it's there
    #echo -e "\n" >> $CLIENT_CONF_DIR/sqoop-env.sh
    echo -e "\nexport HADOOP_CLASSPATH=\$HADOOP_CLASSPATH:$EXTRA_CLASSPATH" >> $CLIENT_CONF_DIR/sqoop-env.sh

    log "Processing has finished successfully"
    exit 0
    ;;    
  
  (*)
    log "Don't understand [$CMD]"
    ;;

esac

