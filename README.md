Cloudera Manager CSDs
=======

A collection of Custom Service Descriptors.

Requirements
------------

 * Maven 3 (to build)

## Building the CSDs

The CSDs can be build by running:

```bash
$ mvn install
```

The CSD itself is a jar file located under the target
directory of each CSD. For Spark, the CSD is located:

```bash
$ ls SPARK/target/SPARK-1.0-SNAPSHOT.jar
```

All source in this repository is [Apache-Licensed](LICENSE.txt).

