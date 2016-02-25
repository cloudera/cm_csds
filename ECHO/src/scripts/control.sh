#!/bin/bash

# Time marker for both stderr and stdout
date; date 1>&2

cmd=$1
paramFile=$2
workerFile=$3
timestamp=$(date)

portNum=""
for line in $(cat $paramFile)
do
  IFS='=' read -a tokens <<< "$line"
  key=${tokens[0]}
  value=${tokens[1]}
  if [ $key = "portNum" ]
   then
    portNum=$value
  fi
done

hostfile="hostlist"
for line in $(cat $workerFile)
do
  IFS=':' read -a tokens <<< "$line"
  host=${tokens[0]}
  echo $host >> $hostfile
done

if [ "start" = "$cmd" ]; then
  echo "$timestamp Starting Server on port $portNum"
  exec python -m SimpleHTTPServer $portNum
elif [ "stop" = "$cmd" ]; then
  echo "$timestamp Stopping Server"
else
  echo "$timestamp Don't understand [$cmd]"
fi
