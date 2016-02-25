#!/bin/bash

# Time marker for both stderr and stdout
date; date 1>&2

timestamp=$(date)
pwd=$(pwd)

echo "$timestamp Running echo deploy client config script"
echo "using $CONF_DIR as CONF_DIR"
echo "pwd is $pwd"
echo "using $@ as args"
echo "ENV1 is $ENV1"
echo "ENV2 is $ENV2"
