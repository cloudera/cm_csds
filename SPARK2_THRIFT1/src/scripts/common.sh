#!/bin/bash
CURRENT_DIRECTORY=$(cd $(dirname $0) && pwd)
cp -r $CURRENT_DIRECTORY/../yarn-conf/ $CURRENT_DIRECTORY/../spark2-ts-conf/
#Delete hive.server2.authentication.kerberos.principal from hive-site.xml
line_number=`grep -in hive.server2.authentication.kerberos.principal $CURRENT_DIRECTORY/../hive-conf/hive-site.xml | cut -d : -f 1`
if [ ! -z "$line_number" ]
then
   start_line_number=$(($line_number -1))
   end_line_number=$(($line_number +2))
   sed -i "${start_line_number},${end_line_number}d" $CURRENT_DIRECTORY/../hive-conf/hive-site.xml
fi
#Delete hive.server2.enable.doAs from hive-site.xml
line_number=`grep -in hive.server2.enable.doAs $CURRENT_DIRECTORY/../hive-conf/hive-site.xml | cut -d : -f 1`
if [ ! -z "$line_number" ]
then
   start_line_number=$(($line_number -1))
   end_line_number=$(($line_number +2))
   sed -i "${start_line_number},${end_line_number}d" $CURRENT_DIRECTORY/../hive-conf/hive-site.xml
fi
#Copy hive-site to yarn and spark conf folders
cp $CURRENT_DIRECTORY/../hive-conf/hive-site.xml $CURRENT_DIRECTORY/../spark2-ts-conf/yarn-conf/
cp $CURRENT_DIRECTORY/../hive-conf/hive-site.xml $CURRENT_DIRECTORY/../spark2-ts-conf/

#Change SPARK_HOME in spark-defaults.conf and spark-env.sh
sed -i "s,CUSTOM_SPARK_HOME,$CUSTOM_SPARK_HOME_DIR,g" $CURRENT_DIRECTORY/../spark2-ts-conf/spark-defaults.conf
sed -i "s,CUSTOM_SPARK_HOME,$CUSTOM_SPARK_HOME_DIR,g" $CURRENT_DIRECTORY/../spark2-ts-conf/spark-env.sh

#Exporting environment variables needed to start spark thrift server
export HADOOP_CONF_DIR=$CURRENT_DIRECTORY/../spark2-ts-conf/yarn-conf
export SPARK_HOME=$CUSTOM_SPARK_HOME_DIR
export SPARK_CONF_DIR=$CURRENT_DIRECTORY/../spark2-ts-conf

function start_thrift_server {
    EXEC_CMD="$CUSTOM_SPARK_HOME_DIR/bin/spark-submit --class org.apache.spark.sql.hive.thriftserver.HiveThriftServer2 1 --master yarn --executor-memory ${SPARK_EXEC_MEM} --driver-memory ${SPARK_DRIVER_MEM} --queue $PORTAL_QUEUE --executor-cores $SPARK_EXEC_CORES --conf spark.dynamicAllocation.maxExecutors=$SPARK_MAX_EXEC --conf spark.dynamicAllocation.minExecutors=$SPARK_MIN_EXEC --conf spark.ui.port=$SPARKTHRIFT_WEBUI_PORT $HISTORY_SERVER_CONFIG --hiveconf hive.server2.thrift.port=$SPARK_THRIFT_SERVER_PORT $SPARKTHRIFT_CMD_OPTS --driver-java-options -Dlog4j.configuration=file:$CURRENT_DIRECTORY/../spark2-ts-conf/log4j.properties"
    if [ "$SPARK_HA_STATUS" = true ] && { [ -z "$SPARK_LOADBALANCER_HOST" ] || [ -z "$SPARK_LOADBALANCER_PORT" ]; }; then
        echo "Load balancer host and port should be defined if HA state is enabled"
        exit 1
    fi
    if [ "$SPARK_HA_STATUS" = true ]; then
	export SCM_KERBEROS_PRINCIPAL=$THRIFT1_LOADBALANCER_PRINCIPAL
        
    else
	export SCM_KERBEROS_PRINCIPAL=$THRIFT1_PRINCIPAL
    fi
#Check if Kerberos is enabled and if so start the service with proper pricipal and keytab
    if [ "$KERBEROS_AUTH_ENABLE" = true ]; then
	export KEYTAB_FILE=$CURRENT_DIRECTORY/../spark_thrift.keytab
    	kinit -kt $KEYTAB_FILE $SCM_KERBEROS_PRINCIPAL
	EXEC_CMD=$EXEC_CMD" --hiveconf hive.server2.authentication.kerberos.principal=$SCM_KERBEROS_PRINCIPAL --hiveconf hive.server2.authentication.kerberos.keytab=$KEYTAB_FILE"
    fi
    echo $EXEC_CMD
    exec $EXEC_CMD
}
