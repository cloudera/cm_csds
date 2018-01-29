#!/bin/bash
. $(cd $(dirname $0) && pwd)/common.sh
case $1 in
  (start_thrift_server)
    start_thrift_server
    ;;

  (*)
    log "Don't understand [$1]"
    exit 1
    ;;
esac
