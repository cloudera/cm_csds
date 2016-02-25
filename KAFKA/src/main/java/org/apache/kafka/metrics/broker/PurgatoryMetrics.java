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

class PurgatoryMetrics {

    private PurgatoryMetrics() {}

    // ProducerRequestPurgatory
    private static final String PRODUCER_REQUEST_PURGATORY_CONTEXT_FORMAT = "kafka.server.ProducerRequestPurgatory::%s";

    private static final CodahaleMetric PRODUCER_PURGATORY_SIZE_METRIC =
            new CodahaleMetric.Builder()
                    .setName("producer_purgatory_size")
                    .setLabel("Requests waiting in the producer purgatory")
                    .setDescription("Requests waiting in the producer purgatory. This should be non-zero when acks = -1 is used in producers")
                    .setNumerator(UnitConstants.requests)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(PRODUCER_REQUEST_PURGATORY_CONTEXT_FORMAT, "PurgatorySize"))
                    .build();

    private static final CodahaleMetric PRODUCER_PURGATORY_DELAYED_REQUESTS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("producer_purgatory_delayed_requests")
                    .setLabel("Number of requests delayed in the producer purgatory")
                    .setDescription("Number of requests delayed in the producer purgatory")
                    .setNumerator(UnitConstants.requests)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(PRODUCER_REQUEST_PURGATORY_CONTEXT_FORMAT, "NumDelayedRequests"))
                    .build();

    // FetchRequestPurgatory
    private static final String FETCH_REQUEST_PURGATORY_CONTEXT_FORMAT = "kafka.server.FetchRequestPurgatory::%s";

    private static final CodahaleMetric FETCH_PURGATORY_SIZE_METRIC =
            new CodahaleMetric.Builder()
                    .setName("fetch_purgatory_size")
                    .setLabel("Requests waiting in the fetch purgatory")
                    .setDescription("Requests waiting in the fetch purgatory. This depends on value of fetch.wait.max.ms in the consumer")
                    .setNumerator(UnitConstants.requests)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(FETCH_REQUEST_PURGATORY_CONTEXT_FORMAT, "PurgatorySize"))
                    .build();

    private static final CodahaleMetric FETCH_PURGATORY_DELAYED_REQUESTS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("fetch_purgatory_delayed_requests")
                    .setLabel("Number of requests delayed in the fetch purgatory")
                    .setDescription("Number of requests delayed in the fetch purgatory")
                    .setNumerator(UnitConstants.requests)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(FETCH_REQUEST_PURGATORY_CONTEXT_FORMAT, "NumDelayedRequests"))
                    .build();


    public static List<CodahaleMetric> getMetrics() {
        return Arrays.asList(
                PRODUCER_PURGATORY_SIZE_METRIC,
                PRODUCER_PURGATORY_DELAYED_REQUESTS_METRIC,
                FETCH_PURGATORY_SIZE_METRIC,
                FETCH_PURGATORY_DELAYED_REQUESTS_METRIC
        );
    }
}
