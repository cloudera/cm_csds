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
import kafka.network.RequestMetrics$;
import org.apache.kafka.metrics.UnitConstants;

import java.util.*;

class RequestMetrics {

    private RequestMetrics() {}

    // KafkaRequestHandlerPool
    private static final String REQUEST_HANDLER_POOL_CONTEXT_FORMAT = "kafka.server.KafkaRequestHandlerPool::%s";

    private static final CodahaleMetric REQUEST_HANDLER_AVG_IDLE_METRIC =
            new CodahaleMetric.Builder()
                    .setName("request_handler_avg_idle")
                    .setLabel("Request Handler Average Idle")
                    .setDescription("The average free capacity of the request handler")
                    .setNumerator(UnitConstants.percent_idle)
                    .setDenominator(UnitConstants.nanoseconds)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(REQUEST_HANDLER_POOL_CONTEXT_FORMAT, "RequestHandlerAvgIdlePercent"))
                    .build();

    // DelayedFetchRequestMetrics
    private static final String DELAYED_FETCH_REQUEST_CONTEXT_FORMAT = "kafka.server.DelayedFetchRequestMetrics::%s";

    private static final CodahaleMetric CONSUMER_EXPIRES_METRIC =
            new CodahaleMetric.Builder()
                    .setName("consumer_expires")
                    .setLabel("Consumer Expires")
                    .setDescription("Number of expired delayed consumer fetch requests")
                    .setNumerator(UnitConstants.requests)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(DELAYED_FETCH_REQUEST_CONTEXT_FORMAT, "ConsumerExpiresPerSecond"))
                    .build();

    private static final CodahaleMetric FOLLOWER_EXPIRES_METRIC =
            new CodahaleMetric.Builder()
                    .setName("follower_expires")
                    .setLabel("Follower Expires")
                    .setDescription("Number of expired delayed follower fetch requests")
                    .setNumerator(UnitConstants.requests)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(DELAYED_FETCH_REQUEST_CONTEXT_FORMAT, "FollowerExpiresPerSecond"))
                    .build();

    // DelayedProducerRequestMetrics
    private static final String DELAYED_PRODUCE_REQUEST_CONTEXT_FORMAT = "kafka.server.DelayedProducerRequestMetrics::%s";

    private static final CodahaleMetric PRODUCER_EXPIRES_METRIC =
            new CodahaleMetric.Builder()
                    .setName("producer_expires")
                    .setLabel("Producer Expires")
                    .setDescription("Number of expired delayed producer requests")
                    .setNumerator(UnitConstants.requests)
                    .setDenominator(UnitConstants.second)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                    .setContext(String.format(DELAYED_PRODUCE_REQUEST_CONTEXT_FORMAT, "ExpiresPerSecond"))
                    .build();

    // RequestMetrics
    private static final String REQUEST_METRICS_CONTEXT_FORMAT = "kafka.network.RequestMetrics.request.%s::%s";

    public static List<CodahaleMetric> getMetrics() {
        List<CodahaleMetric> metrics = new ArrayList<CodahaleMetric>();
        for(String requestName : getKafkaRequestNames()) {
            metrics.add(REQUEST_HANDLER_AVG_IDLE_METRIC);
            metrics.add(CONSUMER_EXPIRES_METRIC);
            metrics.add(FOLLOWER_EXPIRES_METRIC);
            metrics.add(PRODUCER_EXPIRES_METRIC);
            metrics.addAll(getMetricsForRequest(requestName));
        }
        return metrics;
    }

    /**
     * Get the list of Kafka request metric names from Kafka.
     * @return a list of all the Kafka request metric names
     */
    private static List<String> getKafkaRequestNames() {
        // This is a little messy due to scala interop
        Map<String, kafka.network.RequestMetrics> metricsMap = scala.collection.JavaConverters
                .mapAsJavaMapConverter(RequestMetrics$.MODULE$.metricsMap()).asJava();
        List<String> metricNames = new ArrayList<String>(metricsMap.keySet());
        Collections.sort(metricNames);
        return metricNames;
    }

    /**
     * Get the list of metrics for a request
     * @param requestName the name of the request
     * @return the list of metrics
     */
    private static List<CodahaleMetric> getMetricsForRequest(final String requestName) {
        final String metricName = requestNameToMetricName(requestName);

        final CodahaleMetric localTimeMetric = new CodahaleMetric.Builder()
                .setName(String.format("%s_local_time", metricName))
                .setLabel(String.format("%s Local Time", requestName))
                .setDescription(String.format("Local Time spent in responding to %s requests", requestName))
                .setNumerator(UnitConstants.ms)
                .setNumeratorForCounterMetric(UnitConstants.requests)
                .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.HISTOGRAM)
                .setContext(String.format(REQUEST_METRICS_CONTEXT_FORMAT, requestName, "LocalTimeMs"))
                .build();

        final CodahaleMetric remoteTimeMetric = new CodahaleMetric.Builder()
                .setName(String.format("%s_remote_time", metricName))
                .setLabel(String.format("%s Remote Time", requestName))
                .setDescription(String.format("Remote Time spent in responding to %s requests", requestName))
                .setNumerator(UnitConstants.ms)
                .setNumeratorForCounterMetric(UnitConstants.requests)
                .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.HISTOGRAM)
                .setContext(String.format(REQUEST_METRICS_CONTEXT_FORMAT, requestName, "RemoteTimeMs"))
                .build();

        final CodahaleMetric requestQueueTimeMetric = new CodahaleMetric.Builder()
                .setName(String.format("%s_request_queue_time", metricName))
                .setLabel(String.format("%s Request Queue Time", requestName))
                .setDescription(String.format("Request Queue Time spent in responding to %s requests", requestName))
                .setNumerator(UnitConstants.ms)
                .setNumeratorForCounterMetric(UnitConstants.requests)
                .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.HISTOGRAM)
                .setContext(String.format(REQUEST_METRICS_CONTEXT_FORMAT, requestName, "RequestQueueTimeMs"))
                .build();

        final CodahaleMetric responseQueueTimeMetric = new CodahaleMetric.Builder()
                .setName(String.format("%s_response_queue_time", metricName))
                .setLabel(String.format("%s Response Queue Time", requestName))
                .setDescription(String.format("Response Queue Time spent in responding to %s requests", requestName))
                .setNumerator(UnitConstants.ms)
                .setNumeratorForCounterMetric(UnitConstants.requests)
                .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.HISTOGRAM)
                .setContext(String.format(REQUEST_METRICS_CONTEXT_FORMAT, requestName, "ResponseQueueTimeMs"))
                .build();

        final CodahaleMetric responseSendTimeMetric = new CodahaleMetric.Builder()
                .setName(String.format("%s_response_send_time", metricName))
                .setLabel(String.format("%s Response Send Time", requestName))
                .setDescription(String.format("Response Send Time spent in responding to %s requests", requestName))
                .setNumerator(UnitConstants.ms)
                .setNumeratorForCounterMetric(UnitConstants.requests)
                .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.HISTOGRAM)
                .setContext(String.format(REQUEST_METRICS_CONTEXT_FORMAT, requestName, "ResponseSendTimeMs"))
                .build();

        final CodahaleMetric totalTimeMetric = new CodahaleMetric.Builder()
                .setName(String.format("%s_total_time", metricName))
                .setLabel(String.format("%s Total Time", requestName))
                .setDescription(String.format("Total Time spent in responding to %s requests", requestName))
                .setNumerator(UnitConstants.ms)
                .setNumeratorForCounterMetric(UnitConstants.requests)
                .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.HISTOGRAM)
                .setContext(String.format(REQUEST_METRICS_CONTEXT_FORMAT, requestName, "TotalTimeMs"))
                .build();

        final CodahaleMetric requestsMetric = new CodahaleMetric.Builder()
                .setName(String.format("%s_requests", metricName))
                .setLabel(String.format("%s Requests", requestName))
                .setDescription(String.format("Number of %s requests", requestName))
                .setNumerator(UnitConstants.requests)
                .setDenominator(UnitConstants.second)
                .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.METER)
                .setContext(String.format(REQUEST_METRICS_CONTEXT_FORMAT, requestName, "RequestsPerSec"))
                .build();

        return Arrays.asList(
                localTimeMetric,
                remoteTimeMetric,
                requestQueueTimeMetric,
                responseQueueTimeMetric,
                responseSendTimeMetric,
                totalTimeMetric,
                requestsMetric
        );
    }

    /**
     * Converts a request name to a metric name.
     * @param requestName the requestName to convert
     * @return the metric name
     */
    private static String requestNameToMetricName(final String requestName) {
        final String regex = "([a-z])([A-Z]+)";
        final String replacement = "$1_$2";
        return requestName.replaceAll(regex,replacement).toLowerCase();
    }
}
