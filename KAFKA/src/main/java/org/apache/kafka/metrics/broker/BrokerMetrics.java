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
import com.google.common.collect.Lists;
import org.apache.kafka.metrics.UnitConstants;

import java.util.List;

public class BrokerMetrics {

    private BrokerMetrics() {}
    
    // KafkaServer
    private static final String KAFKA_SERVER_CONTEXT_FORMAT = "kafka.server.KafkaServer::%s";

    private static final CodahaleMetric BROKER_STATE_METRIC =
            new CodahaleMetric.Builder()
                    .setName("broker_state")
                    .setLabel("Broker State")
                    .setDescription("The state the broker is in. 0 = NotRunning, 1 = Starting, " +
                            "2 = RecoveringFromUncleanShutdown, 3 = RunningAsBroker, 4 = RunningAsController, " +
                            "6 = PendingControlledShutdown, 7 = BrokerShuttingDown")
                    .setNumerator(UnitConstants.state)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(KAFKA_SERVER_CONTEXT_FORMAT, "BrokerState"))
                    .build();

    // LogFlushStats
    private static final String LOG_FLUSH_STATS_CONTEXT_FORMAT = "kafka.log.LogFlushStats::%s";

    private static final CodahaleMetric LOG_FLUSH_METRIC =
            new CodahaleMetric.Builder()
                    .setName("log_flush")
                    .setLabel("Log Flush")
                    .setDescription("Rate of flushing Kafka logs to disk")
                    .setNumerator(UnitConstants.ms)
                    .setNumeratorForCounterMetric(UnitConstants.flushes)
                    .setDenominatorForRateMetrics(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.TIMER)
                    .setContext(String.format(LOG_FLUSH_STATS_CONTEXT_FORMAT, "LogFlushRateAndTimeMs"))
                    .build();

    // OffsetManager
    private static final String OFFSET_MANAGER_CONTEXT_FORMAT = "kafka.server.OffsetManager::%s";

    private static final CodahaleMetric NUM_GROUPS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("offsets_groups")
                    .setLabel("Offsets Groups")
                    .setDescription("The number of consumer groups in the offsets cache")
                    .setNumerator(UnitConstants.groups)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(OFFSET_MANAGER_CONTEXT_FORMAT, "NumGroups"))
                    .build();

    private static final CodahaleMetric NUM_OFFSETS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("offsets")
                    .setLabel("Offsets")
                    .setDescription("The size of the offsets cache")
                    .setNumerator(UnitConstants.groups)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(OFFSET_MANAGER_CONTEXT_FORMAT, "NumOffsets"))
                    .build();

    public static List<CodahaleMetric> getMetrics() {
        List<CodahaleMetric> metrics = Lists.newArrayList();
        metrics.add(BROKER_STATE_METRIC);
        metrics.add(LOG_FLUSH_METRIC);
        metrics.add(NUM_GROUPS_METRIC);
        metrics.add(NUM_OFFSETS_METRIC);
        metrics.addAll(BrokerTopicMetrics.getMetrics());
        metrics.addAll(ControllerMetrics.getMetrics());
        metrics.addAll(NetworkMetrics.getMetrics());
        metrics.addAll(PurgatoryMetrics.getMetrics());
        metrics.addAll(ReplicaManagerMetrics.getMetrics());
        metrics.addAll(RequestMetrics.getMetrics());
        return metrics;
    }
}
