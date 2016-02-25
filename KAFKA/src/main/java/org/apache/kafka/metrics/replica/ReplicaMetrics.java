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
package org.apache.kafka.metrics.replica;

import com.cloudera.csd.tools.codahale.CodahaleMetric;
import com.cloudera.csd.tools.codahale.CodahaleMetricTypes;
import org.apache.kafka.metrics.UnitConstants;

import java.util.Arrays;
import java.util.List;

/**
 * Note: The context is missing its "root" because that is generated per replica in CM
 */
public class ReplicaMetrics {

    private ReplicaMetrics() {}

    private static final CodahaleMetric LOG_END_OFFSET_METRIC =
            new CodahaleMetric.Builder()
                    .setName("log_end_offset")
                    .setLabel("Log End Offset")
                    .setDescription("The offset of the next message that will be appended to the log")
                    .setNumerator(UnitConstants.offset)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext("LogEndOffset")
                    .build();

    private static final CodahaleMetric LOG_START_OFFSET_METRIC =
            new CodahaleMetric.Builder()
                    .setName("log_start_offset")
                    .setLabel("Log Start Offset")
                    .setDescription("The earliest message offset in the log")
                    .setNumerator(UnitConstants.offset)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext("LogStartOffset")
                    .build();

    private static final CodahaleMetric NUM_LOG_SEGMENTS_METRIC =
            new CodahaleMetric.Builder()
                    .setName("num_log_segments")
                    .setLabel("Number of log segments")
                    .setDescription("The number of segments in the log")
                    .setNumerator(UnitConstants.segments)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext("NumLogSegments")
                    .build();

    private static final CodahaleMetric SIZE_METRIC =
            new CodahaleMetric.Builder()
                    .setName("size")
                    .setLabel("Log size")
                    .setDescription("The size of the log")
                    .setNumerator(UnitConstants.bytes)
                    .setCodahaleMetricType(CodahaleMetricTypes.CodahaleMetricType.GAUGE)
                    .setContext("Size")
                    .build();

    public static List<CodahaleMetric> getMetrics() {
        return Arrays.asList(
                LOG_END_OFFSET_METRIC,
                LOG_START_OFFSET_METRIC,
                NUM_LOG_SEGMENTS_METRIC,
                SIZE_METRIC
        );
    }
}
