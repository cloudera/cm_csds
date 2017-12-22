This CSD can be used to add Spark2 ThriftServer as a service to Cloudera Manager.
Following are the dependancies before adding Spark2 TS1 service:
1. This CSD has a dependancy on Spark2 service which needs to be installed on the cluster before trying to install this service.
2. The nodes on which Spark2 TS1 is added should also have Spark2 Gateways roles present.
3. The distribution of Spark2 supported by Cloudera doesn't have Spark Thriftserver support hence you need to build one with Thriftserver support.You can follow this   link https://www.linkedin.com/pulse/running-spark-2xx-cloudera-hadoop-distro-cdh-deenar-toraskar-cfa/
   to create one that can be used with this Spark2 TS1 service.
4. The property Custom Spark Home needs to point to the location where the Custom Spark tar file created in the above step has been extracted.  
5. To enable high availability for multiple Spark2 ThriftServer hosts, configure a load balancer to manage them  and enable the property sparkthrift.ha.enable to yes   and fill up the sparkthrift.loadbalancer.host and sparkthrift.loadbalancer.port property with respective values.
6. The logs can be viewed at /var/log/sparkthrift
7. The service runs as hive user and port 20000 by default
