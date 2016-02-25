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

class ControllerMetrics {

    private ControllerMetrics() {}

    // ControllerStats
    private static final String CONTROLLER_STATS_CONTEXT_FORMAT = "kafka.controller.ControllerStats::%s";

    private static final CodahaleMetric LEADER_ELECTIONS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("leader_election")
                    .setLabel("Leader Elections")
                    .setDescription("Leader elections")
                    .setNumerator(UnitConstants.ms)
                    .setNumeratorForCounterMetric(UnitConstants.elections)
                    .setDenominatorForRateMetrics(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.TIMER)
                    .setContext(String.format(CONTROLLER_STATS_CONTEXT_FORMAT, "LeaderElectionRateAndTimeMs"))
                    .build();

    private static final CodahaleMetric UNCLEAN_LEADER_ELECTIONS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("unclean_leader_elections")
                    .setLabel("Unclean Leader Elections")
                    .setDescription("Unclean leader elections. We recommend disabling unclean leader elections, " +
                            "to avoid potential data loss, so this should be 0")
                    .setNumerator(UnitConstants.elections)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(CONTROLLER_STATS_CONTEXT_FORMAT, "UncleanLeaderElectionsPerSec"))
                    .build();


    // KafkaController
    private static final String KAFKA_CONTROLLER_CONTEXT_FORMAT = "kafka.controller.KafkaController::%s";

    private static final CodahaleMetric ACTIVE_CONTROLLER_METRIC =
            new CodahaleMetric.Builder()
                    .setName("active_controller")
                    .setLabel("Active Controller")
                    .setDescription("Will be 1 if this broker is the active controller, 0 otherwise")
                    .setNumerator(UnitConstants.controller)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(KAFKA_CONTROLLER_CONTEXT_FORMAT, "ActiveControllerCount"))
                    .build();

    private static final CodahaleMetric PREFERRED_REPLICA_IMBALANCE_METRIC =
            new CodahaleMetric.Builder()
                    .setName("preferred_replica_imbalance")
                    .setLabel("Preferred Replica Imbalance")
                    .setDescription("Number of partitions where the lead replica is not the preferred replica")
                    .setNumerator(UnitConstants.partitions)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(KAFKA_CONTROLLER_CONTEXT_FORMAT, "PreferredReplicaImbalanceCount"))
                    .build();

    private static final CodahaleMetric OFFLINE_PARTITIONS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("offline_partitions")
                    .setLabel("Offline Partitions")
                    .setDescription("Number of unavailable partitions")
                    .setNumerator(UnitConstants.partitions)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(KAFKA_CONTROLLER_CONTEXT_FORMAT, "OfflinePartitionsCount"))
                    .build();

    public static List<CodahaleMetric> getMetrics() {
        return Arrays.asList(
                LEADER_ELECTIONS_METRIC,
                UNCLEAN_LEADER_ELECTIONS_METRIC,
                ACTIVE_CONTROLLER_METRIC,
                PREFERRED_REPLICA_IMBALANCE_METRIC,
                OFFLINE_PARTITIONS_METRIC
        );
    }
}
