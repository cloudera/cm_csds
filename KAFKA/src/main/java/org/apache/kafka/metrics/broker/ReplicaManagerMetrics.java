/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.kafka.metrics.broker;

import com.cloudera.csd.tools.codahale.CodahaleMetric;
import com.cloudera.csd.tools.codahale.CodahaleMetricTypes;
import org.apache.kafka.metrics.UnitConstants;

import java.util.Arrays;
import java.util.List;

class ReplicaManagerMetrics {

    private ReplicaManagerMetrics() {}

    // ReplicaManager
    private static final String REPLICA_MANAGER_CONTEXT_FORMAT = "kafka.server.ReplicaManager::%s";

    private static final CodahaleMetric PARTITIONS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("partitions")
                    .setLabel("Partitions")
                    .setDescription("Number of partitions (lead or follower replicas) on broker")
                    .setNumerator(UnitConstants.partitions)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(REPLICA_MANAGER_CONTEXT_FORMAT, "PartitionCount"))
                    .build();

    private static final CodahaleMetric LEADER_REPLICAS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("leader_replicas")
                    .setLabel("Leader Replicas")
                    .setDescription("Number of leader replicas on broker")
                    .setNumerator(UnitConstants.replicas)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(REPLICA_MANAGER_CONTEXT_FORMAT, "LeaderCount"))
                    .build();

    private static final CodahaleMetric UNDER_REPLICATED_PARTITIONS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("under_replicated_partitions")
                    .setLabel("Under Replicated Partitions")
                    .setDescription("Number of partitions with unavailable replicas")
                    .setNumerator(UnitConstants.partitions)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(REPLICA_MANAGER_CONTEXT_FORMAT, "UnderReplicatedPartitions"))
                    .build();

    private static final CodahaleMetric ISR_EXPANDS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("isr_expands")
                    .setLabel("ISR Expansions")
                    .setDescription("Number of times ISR for a partition expanded")
                    .setNumerator(UnitConstants.expansions)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(REPLICA_MANAGER_CONTEXT_FORMAT, "IsrExpandsPerSec"))
                    .build();

    private static final CodahaleMetric ISR_SHRINKS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("isr_shrinks")
                    .setLabel("ISR Shrinks")
                    .setDescription("Number of times ISR for a partition shrank")
                    .setNumerator(UnitConstants.shrinks)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(REPLICA_MANAGER_CONTEXT_FORMAT, "IsrShrinksPerSec"))
                    .build();

    // ReplicaFetcherManager
    private static final String REPLICA_FETCHER_MANAGER_CONTEXT_FORMAT = "kafka.server.ReplicaFetcherManager.clientId.Replica::%s";

    private static final CodahaleMetric MAX_REPLICATION_LAG_METRIC =
            new CodahaleMetric.Builder()
                    .setName("max_replication_lag")
                    .setLabel("Maximum Replication Lag on Broker")
                    .setDescription("Maximum replication lag on broker, across all fetchers, topics and partitions")
                    .setNumerator(UnitConstants.messages)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(REPLICA_FETCHER_MANAGER_CONTEXT_FORMAT, "MaxLag"))
                            .build();

    private static final CodahaleMetric MIN_REPLICATION_RATE =
            new CodahaleMetric.Builder()
                    .setName("min_replication_rate")
                    .setLabel("Minimum Replication Rate")
                    .setDescription("Minimum replication rate, across all fetchers, topics and partitions. Measured in average fetch requests per sec in the last minute")
                    .setNumerator(UnitConstants.fetchRequests)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(REPLICA_FETCHER_MANAGER_CONTEXT_FORMAT, "MinFetchRate"))
                    .build();

    public static List<CodahaleMetric> getMetrics() {
        return Arrays.asList(
                PARTITIONS_METRIC,
                LEADER_REPLICAS_METRIC,
                UNDER_REPLICATED_PARTITIONS_METRIC,
                ISR_EXPANDS_METRIC,
                ISR_SHRINKS_METRIC,
                MAX_REPLICATION_LAG_METRIC,
                MIN_REPLICATION_RATE
        );
    }
}
