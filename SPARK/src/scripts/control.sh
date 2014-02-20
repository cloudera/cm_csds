#!/bin/bash
##
# Copyright (c) 2014 Cloudera, Inc. All rights reserved.
##

# Time marker for both stderr and stdout
date; date 1>&2

CMD=$1
MASTER_FILE=$2

DEFAULT_SPARK_HOME=/usr/lib/spark

export SPARK_HOME=${SPARK_HOME:-$CDH_SPARK_HOME}
export HADOOP_HOME=${HADOOP_HOME:-$CDH_HADOOP_HOME}

# If SPARK_HOME is not set, make it the default
export SPARK_HOME=${SPARK_HOME:-$DEFAULT_SPARK_HOME}

function log {
  timestamp=$(date)
  echo "$timestamp: $1"
}

if [ ! -z $MASTER_FILE ]; then
  MASTER_IP=
  MASTER_PORT=
  for line in $(cat $MASTER_FILE)
  do
    IFS=':' read -a tokens <<< "$line"
    host=${tokens[0]}
    property=${tokens[1]}
  
    IFS='=' read -a tokens <<< "$property"
    key=${tokens[0]}
    value=${tokens[1]}
  
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

# Copy the log4j directory to the config directory.
cp $CONF_DIR/log4j.properties $SPARK_CONF_DIR/.

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

  (*)
    log "Don't understand [$CMD]"
    ;;

esac
ARGS+=($ADDITIONAL_ARGS)

cmd="$SPARK_HOME/bin/spark-class ${ARGS[@]}"
echo "Running [$cmd]"
exec $cmd
