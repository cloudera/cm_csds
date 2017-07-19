#!/bin/bash

# Copyright (c) 2017 Cloudera, Inc. All rights reserved.

# This is a bash test script for kafka sentry version check changes to fix
# OPSAPS-37907 and OPSAPS-38677

# for debugging
set -x

# Resets the given test directory and populates the following variables:
# * TEST_DIR
# * CONF_DIR
# * KAFKA_HOME
# * CDH_SENTRY_HOME
#
# Creates Kafka and Sentry version files as appropriate.
# Creates sentry-conf/sentry_site.xml as appropriate.
# Creates a fake kafka-server-start script.
#
# Takes arguments:
# 1: KAFKA_VER - full version string for Kafka, like 0.10.0-kafka2.1.1.
#                Can also be "skip" to avoid creating the Kafka version file
#                altogether.
# 2: SENTRY_VER - full version string for Sentry, like 1.5.1-cdh5.11.0. Can
#                 also be "skip" to avoid creating the Sentry version file
#                 altogether.
# 3: CONFIGURE_SENTRY_SITE - "true" or "false" to indicate whether to create the sentry-site.xml file
setup_test_directory() {
  if [ $# -ne 3 ]; then
    echo expected 3 arguments: KAFKA_VER, SENTRY_VER, CONFIGURE_SENTRY_SITE
    exit 1;
  fi

  TEST_DIR="target/test/kafka_sentry_${NUM}"
  if [[ ${1} == "skip" ]]; then
    KAFKA_VER=
  else
    KAFKA_VER=$1
  fi
  if [[ ${2} == "skip" ]]; then
    SENTRY_VER=
  else
    SENTRY_VER=$2
  fi
  CONFIGURE_SENTRY_SITE=$3

  if [ -d $TEST_DIR ]; then
    rm -r $TEST_DIR
  fi
  mkdir -p $TEST_DIR

  export CONF_DIR=$TEST_DIR/conf_dir
  mkdir $CONF_DIR

  export KAFKA_HOME=$TEST_DIR/kafka_home
  mkdir $KAFKA_HOME
  mkdir $KAFKA_HOME/bin
  echo "#!/bin/bash" >> $KAFKA_HOME/bin/kafka-server-start.sh
  echo "echo fake start Kafka" >> $KAFKA_HOME/bin/kafka-server-start.sh
  chmod +x $KAFKA_HOME/bin/kafka-server-start.sh
  if [[ -n ${KAFKA_VER} ]]; then
    mkdir $KAFKA_HOME/cloudera
    echo "version=${KAFKA_VER}" >> $KAFKA_HOME/cloudera/cdh_version.properties
  fi

  export CDH_SENTRY_HOME=$TEST_DIR/sentry_home
  if [[ -n ${SENTRY_VER} ]]; then
    mkdir $CDH_SENTRY_HOME
    mkdir $CDH_SENTRY_HOME/cloudera
    echo "version=${SENTRY_VER}" >> $CDH_SENTRY_HOME/cloudera/cdh_version.properties
  fi

  if [[ ${CONFIGURE_SENTRY_SITE} == "true" ]]; then
    mkdir $CONF_DIR/sentry-conf
    touch $CONF_DIR/sentry-conf/sentry-site.xml
  fi
}

# return 0 (true) if kafka.properties has sentry configs
verify_kafka_properties_has_sentry() {
  if [[ ! -e $CONF_DIR/kafka.properties ]]; then
    echo "no"
  else
    grep -q sentry $CONF_DIR/kafka.properties
    if [[ $? -eq 0 ]]; then
      echo "yes"
    else
      echo "no"
    fi
  fi
}

add_error() {
  echo $1 >> $TEST_DIR/errors.log
  >&2 echo $1
  if [[ -z ${ERRORS} ]]; then
    ERRORS=$1
  else
    ERRORS="${ERRORS}; $1"
  fi
}

KAFKA_CONTROL=../src/scripts/control.sh
echo "control script missing the execute bit, but we'll want that to test"
chmod +x $KAFKA_CONTROL

# versions taken from nightly5{8,9,10}-1.gce.cloudera.com
KAFKA_58=0.9.0-kafka2.0.1
KAFKA_59=0.10.0-kafka2.1.0
SENTRY_58=1.5.1-cdh5.8.5-SNAPSHOT
SENTRY_59=1.5.1-cdh5.9.2-SNAPSHOT
SENTRY_510=1.5.1-cdh5.10.1-SNAPSHOT
# Future major version bumps made up, they don't exist yet
# Minor is intentionally less than the minor of first version supporting feature
KAFKA_FUTURE=20.0.0-kafka11.0.0-SNAPSHOT
SENTRY_FUTURE=20.0.0-cdh13.0.0

NUM=1
echo "Test $NUM - Happy path - Sentry, Kafka 2.1, CDH 5.10"
setup_test_directory $KAFKA_59 $SENTRY_59 true
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "no" ]]; then
    add_error "Test $NUM expected sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi

NUM=$(($NUM + 1))
echo "Test $NUM - Sentry ignored because Kafka too old"
setup_test_directory $KAFKA_58 $SENTRY_59 true
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "yes" ]]; then
    add_error "Test $NUM expected no sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi

NUM=$(($NUM + 1))
echo "Test $NUM - Sentry ignored because CDH too old"
setup_test_directory $KAFKA_59 $SENTRY_58 true
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "yes" ]]; then
    add_error "Test $NUM expected no sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi

NUM=$(($NUM + 1))
echo "Test $NUM - Sentry ignored because not configured"
setup_test_directory $KAFKA_59 $SENTRY_59 false
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "yes" ]]; then
    add_error "Test $NUM expected no sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi

NUM=$(($NUM + 1))
echo "Test $NUM - Sentry ignored because both Kafka and Sentry too old"
setup_test_directory $KAFKA_58 $SENTRY_58 true
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "yes" ]]; then
    add_error "Test $NUM expected no sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi

NUM=$(($NUM + 1))
echo "Test $NUM - Sentry ignored because Kafka version unspecified"
setup_test_directory "skip" $SENTRY_59 true
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "yes" ]]; then
    add_error "Test $NUM expected no sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi

NUM=$(($NUM + 1))
echo "Test $NUM - Sentry ignored because Sentry version unspecified"
setup_test_directory $KAFKA_59 "skip" true
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "yes" ]]; then
    add_error "Test $NUM expected no sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi

NUM=$(($NUM + 1))
echo "Test $NUM - Sentry ignored because both versions unspecified"
setup_test_directory "skip" "skip" true
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "yes" ]]; then
    add_error "Test $NUM expected no sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi


NUM=$(($NUM + 1))
echo "Test $NUM - Kafka59 Sentry510, exercising 2 digit minor version"
setup_test_directory $KAFKA_59 $SENTRY_510 true
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "no" ]]; then
    add_error "Test $NUM expected sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi

NUM=$(($NUM + 1))
echo "Test $NUM - newer major version of Kafka and Sentry, lower minor version"
setup_test_directory $KAFKA_FUTURE $SENTRY_FUTURE true
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "no" ]]; then
    add_error "Test $NUM expected sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi

NUM=$(($NUM + 1))
echo "Test $NUM - Versions proper, but CDH_SENTRY_HOME not set"
setup_test_directory $KAFKA_59 $SENTRY_59 true
export CDH_SENTRY_HOME=
$KAFKA_CONTROL
if [[ $? -ne 0 ]]; then
  add_error "Test $NUM control script hit an error"
else
  if [[ $(verify_kafka_properties_has_sentry) == "yes" ]]; then
    add_error "Test $NUM expected no sentry properties"
  else
    echo "Test $NUM Success!"
  fi
fi

echo "cleanup: reset execute bit on control script"
chmod -x $KAFKA_CONTROL

if [[ -n ${ERRORS} ]]; then
  echo "FAILED due to: ${ERRORS}"
  exit 1;
fi
echo "Successfully ran all $NUM tests!"

