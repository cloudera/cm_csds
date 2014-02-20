##
# Copyright (c) 2014 Cloudera, Inc. All rights reserved.
##

test -z "$ACCUMULO_GENERAL_OPTS" && export ACCUMULO_GENERAL_OPTS="{{accumulo_general_opts}}"
test -z "$ACCUMULO_OTHER_OPTS" && export ACCUMULO_OTHER_OPTS="{{accumulo_other_opts}}"
export MONITOR='unused'
export ACCUMULO_VERIFY_ONLY='true'
