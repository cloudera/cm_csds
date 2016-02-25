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

class BrokerTopicMetrics {

    private BrokerTopicMetrics() {}

    private static final String BROKER_TOPICS_METRICS_CONTEXT_FORMAT = "kafka.server.BrokerTopicMetrics::%s";

    private static final CodahaleMetric MESSAGES_RECEIVED_METRIC =
            new CodahaleMetric.Builder()
                    .setName("messages_received")
                    .setLabel("Messages Received")
                    .setDescription("Number of messages written to topic on this broker")
                    .setNumerator(UnitConstants.messages)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(BROKER_TOPICS_METRICS_CONTEXT_FORMAT, "MessagesInPerSec"))
                    .build();

    private static final CodahaleMetric BYTES_RECEIVED_METRIC =
            new CodahaleMetric.Builder()
                    .setName("bytes_received")
                    .setLabel("Bytes Received")
                    .setDescription("Amount of data written to topic on this broker")
                    .setNumerator(UnitConstants.bytes)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(BROKER_TOPICS_METRICS_CONTEXT_FORMAT, "BytesInPerSec"))
                    .build();

    private static final CodahaleMetric BYTES_FETCHED_METRIC =
            new CodahaleMetric.Builder()
                    .setName("bytes_fetched")
                    .setLabel("Bytes Fetched")
                    .setDescription("Amount of data consumers fetched from this topic on this broker")
                    .setNumerator(UnitConstants.bytes)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(BROKER_TOPICS_METRICS_CONTEXT_FORMAT, "BytesOutPerSec"))
                    .build();

    private static final CodahaleMetric BYTES_REJECTED_METRIC =
            new CodahaleMetric.Builder()
                    .setName("bytes_rejected")
                    .setLabel("Bytes Rejected")
                    .setDescription("Amount of data in messages rejected by broker for this topic")
                    .setNumerator(UnitConstants.bytes)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(BROKER_TOPICS_METRICS_CONTEXT_FORMAT, "BytesRejectedPerSec"))
                    .build();

    private static final CodahaleMetric REJECTED_MESSAGE_BATCHES_METRIC =
            new CodahaleMetric.Builder()
                    .setName("rejected_message_batches")
                    .setLabel("Rejected Message Batches")
                    .setDescription("Number of message batches sent by producers that the broker rejected for this topic")
                    .setNumerator(UnitConstants.message_batches)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(BROKER_TOPICS_METRICS_CONTEXT_FORMAT, "FailedProduceRequestsPerSec"))
                    .build();

    private static final CodahaleMetric FETCH_REQUEST_FAILURES_METRIC =
            new CodahaleMetric.Builder()
                    .setName("fetch_request_failures")
                    .setLabel("Fetch Request Failures")
                    .setDescription("Number of data read requests from consumers that brokers failed to process for this topic")
                    .setNumerator(UnitConstants.fetch_requests)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(BROKER_TOPICS_METRICS_CONTEXT_FORMAT, "FailedFetchRequestsPerSec"))
                    .build();

    public static List<CodahaleMetric> getMetrics() {
        return Arrays.asList(
                MESSAGES_RECEIVED_METRIC,
                BYTES_RECEIVED_METRIC,
                BYTES_FETCHED_METRIC,
                BYTES_REJECTED_METRIC,
                REJECTED_MESSAGE_BATCHES_METRIC,
                FETCH_REQUEST_FAILURES_METRIC
        );
    }
}
