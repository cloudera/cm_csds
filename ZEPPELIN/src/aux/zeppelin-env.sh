
# export JAVA_HOME=
# export MASTER=                              # Spark master url. eg. spark://master_addr:7077. Leave empty if you want to use local mode.
export MASTER=yarn-client

# export ZEPPELIN_JAVA_OPTS                   # Additional jvm options. for example, export ZEPPELIN_JAVA_OPTS="-Dspark.executor.memory=8g -Dspark.cores.max=16"
# export ZEPPELIN_MEM                         # Zeppelin jvm mem options Default -Xms1024m -Xmx1024m -XX:MaxPermSize=512m
# export ZEPPELIN_INTP_MEM                    # zeppelin interpreter process jvm mem options. Default -Xms1024m -Xmx1024m -XX:MaxPermSize=512m
# export ZEPPELIN_INTP_JAVA_OPTS              # zeppelin interpreter process jvm options.
# export ZEPPELIN_SSL_PORT                    # ssl port (used when ssl environment variable is set to true)

# export ZEPPELIN_LOG_DIR                     # Where log files are stored.  PWD by default.
# export ZEPPELIN_PID_DIR                     # The pid files are stored. ${ZEPPELIN_HOME}/run by default.

#Provided by default through service.sdl. This is to escape the setting of log directory to interpreters in interpreters.sh
export ZEPPELIN_LOG_DIR="/"
export ZEPPELIN_PID_DIR="/var/run/zeppelin"

# export ZEPPELIN_WAR_TEMPDIR                 # The location of jetty temporary directory.
# export ZEPPELIN_NOTEBOOK_DIR                # Where notebook saved
# export ZEPPELIN_NOTEBOOK_HOMESCREEN         # Id of notebook to be displayed in homescreen. ex) 2A94M5J1Z
# export ZEPPELIN_NOTEBOOK_HOMESCREEN_HIDE    # hide homescreen notebook from list when this value set to "true". default "false"
# export ZEPPELIN_NOTEBOOK_S3_BUCKET          # Bucket where notebook saved
# export ZEPPELIN_NOTEBOOK_S3_ENDPOINT        # Endpoint of the bucket
# export ZEPPELIN_NOTEBOOK_S3_USER            # User in bucket where notebook saved. For example bucket/user/notebook/2A94M5J1Z/note.json
# export ZEPPELIN_IDENT_STRING                # A string representing this instance of zeppelin. $USER by default.
# export ZEPPELIN_NICENESS                    # The scheduling priority for daemons. Defaults to 0.
# export ZEPPELIN_INTERPRETER_LOCALREPO       # Local repository for interpreter's additional dependency loading
# export ZEPPELIN_NOTEBOOK_STORAGE            # Refers to pluggable notebook storage class, can have two classes simultaneously with a sync between them (e.g. local and remote).
# export ZEPPELIN_NOTEBOOK_ONE_WAY_SYNC       # If there are multiple notebook storages, should we treat the first one as the only source of truth?
# export ZEPPELIN_NOTEBOOK_PUBLIC             # Make notebook public by default when created, private otherwise
export ZEPPELIN_INTP_CLASSPATH_OVERRIDES="/var/lib/zeppelin/conf/external-dependency-conf"
#### Spark interpreter configuration ####

## Kerberos ticket refresh setting
##
export KINIT_FAIL_THRESHOLD=5
export KERBEROS_REFRESH_INTERVAL=1d
export SPARK_HOME="${PARCELS_ROOT}/CDH/lib/spark"

## Use provided spark installation ##
## defining SPARK_HOME makes Zeppelin run spark interpreter process using spark-submit
##
# export SPARK_HOME                           # (required) When it is defined, load it instead of Zeppelin embedded Spark libraries
# export SPARK_HOME=
# export SPARK_SUBMIT_OPTIONS                 # (optional) extra options to pass to spark submit. eg) "--driver-memory 512M --executor-memory 1G".
# export SPARK_APP_NAME                       # (optional) The name of spark application.

## Use embedded spark binaries ##
## without SPARK_HOME defined, Zeppelin still able to run spark interpreter process using embedded spark binaries.
## however, it is not encouraged when you can define SPARK_HOME
##
# Options read in YARN client mode
# export HADOOP_CONF_DIR                      # yarn-site.xml is located in configuration directory in HADOOP_CONF_DIR.
export HADOOP_CONF_DIR={{HADOOP_CONF_DIR}}
# Pyspark (supported with Spark 1.2.1 and above)
# To configure pyspark, you need to set spark distribution's path to 'spark.home' property in Interpreter setting screen in Zeppelin GUI
# export PYSPARK_PYTHON                       # path to the python command. must be the same path on the driver(Zeppelin) and all workers.
# export PYTHONPATH

## Spark interpreter options ##
##
# export ZEPPELIN_SPARK_USEHIVECONTEXT        # Use HiveContext instead of SQLContext if set true. true by default.
# export ZEPPELIN_SPARK_CONCURRENTSQL         # Execute multiple SQL concurrently if set true. false by default.
# export ZEPPELIN_SPARK_IMPORTIMPLICIT        # Import implicits, UDF collection, and sql if set true. true by default.
# export ZEPPELIN_SPARK_MAXRESULT             # Max number of Spark SQL result to display. 1000 by default.
# export ZEPPELIN_WEBSOCKET_MAX_TEXT_MESSAGE_SIZE       # Size in characters of the maximum text message to be received by websocket. Defaults to 1024000


#### HBase interpreter configuration ####

## To connect to HBase running on a cluster, either HBASE_HOME or HBASE_CONF_DIR must be set

# export HBASE_HOME=                          # (require) Under which HBase scripts and configuration should be
# export HBASE_CONF_DIR=                      # (optional) Alternatively, configuration directory can be set to point to the directory that has hbase-site.xml

# export ZEPPELIN_IMPERSONATE_CMD             # Optional, when user want to run interpreter as end web user. eg) 'sudo -H -u ${ZEPPELIN_IMPERSONATE_USER} bash -c '
