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

class NetworkMetrics {

    private NetworkMetrics() {}

    // RequestChannel
    private static final String REQUEST_CHANNEL_CONTEXT_FORMAT = "kafka.network.RequestChannel::%s";

    private static final CodahaleMetric REQUEST_QUEUE_SIZE_METRIC =
            new CodahaleMetric.Builder()
                    .setName("request_queue_size")
                    .setLabel("Request Queue Size")
                    .setDescription("Request Queue Size")
                    .setNumerator(UnitConstants.requests)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(REQUEST_CHANNEL_CONTEXT_FORMAT, "RequestQueueSize"))
                    .build();

    private static final CodahaleMetric RESPONSE_QUEUE_SIZE_METRIC =
            new CodahaleMetric.Builder()
                    .setName("response_queue_size")
                    .setLabel("Response Queue Size")
                    .setDescription("Response Queue Size")
                    .setNumerator(UnitConstants.responses)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(REQUEST_CHANNEL_CONTEXT_FORMAT, "ResponseQueueSize"))
                    .build();

    // SocketServer
    private static final String SOCKET_SERVER_CONTEXT_FORMAT = "kafka.network.SocketServer::%s";

    private static final CodahaleMetric NETWORK_PROCESSOR_AVG_IDLE_METRIC =
            new CodahaleMetric.Builder()
                    .setName("network_processor_avg_idle")
                    .setLabel("Network Processor Average Idle")
                    .setDescription("The average free capacity of the network processors")
                    .setNumerator(UnitConstants.percent_idle)
                    .setDenominator(UnitConstants.nanoseconds)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(SOCKET_SERVER_CONTEXT_FORMAT, "NetworkProcessorAvgIdle"))
                    .build();

    private static final CodahaleMetric RESPONSES_BEING_SENT_METRIC =
            new CodahaleMetric.Builder()
                    .setName("responses_being_sent")
                    .setLabel("Responses Being Sent")
                    .setDescription("The number of responses being sent by the network processors")
                    .setNumerator(UnitConstants.responses)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext(String.format(SOCKET_SERVER_CONTEXT_FORMAT, "ResponsesBeingSent"))
                    .build();

    public static List<CodahaleMetric> getMetrics() {
        return Arrays.asList(
                REQUEST_QUEUE_SIZE_METRIC,
                RESPONSE_QUEUE_SIZE_METRIC,
                NETWORK_PROCESSOR_AVG_IDLE_METRIC,
                RESPONSES_BEING_SENT_METRIC
        );
    }

}
