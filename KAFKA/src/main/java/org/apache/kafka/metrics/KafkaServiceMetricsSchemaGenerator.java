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
package org.apache.kafka.metrics;

import com.cloudera.csd.descriptors.MetricDescriptor;
import com.cloudera.csd.tools.JsonUtil;
import com.cloudera.csd.tools.codahale.AbstractCodahaleFixtureGenerator;
import com.cloudera.csd.tools.codahale.CodahaleCommonMetricSets;
import com.cloudera.csd.tools.codahale.CodahaleCommonMetricSets.MetricServlet2XAdapter;
import com.cloudera.csd.tools.codahale.CodahaleCommonMetricSets.MetricSet;
import com.cloudera.csd.tools.codahale.CodahaleCommonMetricSets.Version;
import com.cloudera.csd.tools.codahale.CodahaleMetricDefinitionFixture;
import com.cloudera.csd.tools.codahale.CodahaleMetric;
import com.google.common.collect.Lists;
import com.google.common.collect.Maps;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.FilenameUtils;
import org.apache.kafka.metrics.broker.BrokerMetrics;
import org.apache.kafka.metrics.replica.ReplicaMetrics;
import org.apache.kafka.metrics.topic.TopicMetrics;

import java.io.File;
import java.util.List;
import java.util.Map;

public class KafkaServiceMetricsSchemaGenerator extends AbstractCodahaleFixtureGenerator {

    private static final String SERVICE_NAME = "KAFKA";

    private static final String KAFKA_BROKER = "KAFKA_BROKER";
    private static final String KAFKA_BROKER_TOPIC = "KAFKA_BROKER_TOPIC";
    private static final String KAFKA_REPLICA = "KAFKA_REPLICA";

    private static final String COMMON_METRICS_FILE_NAME = "common_metrics_fixture.json";

    public KafkaServiceMetricsSchemaGenerator(String[] args) throws Exception {
        super(args);
    }

    /**
     * Generate the fixture.
     */
    @Override
    public CodahaleMetricDefinitionFixture generateFixture() throws Exception {
        final CodahaleMetricDefinitionFixture ret = new CodahaleMetricDefinitionFixture();

        ret.setServiceName(SERVICE_NAME);

        for (CodahaleMetric metric : BrokerMetrics.getMetrics()) {
            ret.addRoleMetric(KAFKA_BROKER, metric);
        }

        for (CodahaleMetric metric: TopicMetrics.getMetrics()) {
            ret.addEntityMetric(KAFKA_BROKER_TOPIC, metric);
        }

        for (CodahaleMetric metric: ReplicaMetrics.getMetrics()) {
            ret.addEntityMetric(KAFKA_REPLICA, metric);
        }

        FileUtils.write(
                new File(config.getString(OPT_GENERATED_OUPTUT.getLongOpt(),
                        CODAHALE_OUT_DEFAULT_FILE_NAME)),
                JsonUtil.valueAsString(ret));
        return ret;
    }

    private void generateCommonMetricsFixture() throws Exception {
        final List<MetricDescriptor> memoryMetricDescriptors =
                CodahaleCommonMetricSets.generateMetricDescritptorsForMetricSet(
                        MetricSet.MEMORY,
                        Version.CODAHALE_2_X_VIRTUAL_MACHINE_METRICS,
                        new MetricServlet2XAdapter("::", MetricSet.MEMORY), SERVICE_NAME);

        final List<MetricDescriptor> threadStateMetricDescriptors =
                CodahaleCommonMetricSets.generateMetricDescritptorsForMetricSet(
                        MetricSet.THREAD_STATE,
                        Version.CODAHALE_2_X_VIRTUAL_MACHINE_METRICS,
                        new MetricServlet2XAdapter("::", MetricSet.THREAD_STATE), SERVICE_NAME);

        final List<MetricDescriptor> commonMetrics = Lists.newArrayList();
        commonMetrics.addAll(memoryMetricDescriptors);
        commonMetrics.addAll(threadStateMetricDescriptors);

        final Map<String, List<MetricDescriptor>> fixture = Maps.newTreeMap();
        fixture.put(KAFKA_BROKER, commonMetrics);

        final String path = FilenameUtils.getFullPath(config.getString(
                AbstractCodahaleFixtureGenerator.OPT_GENERATED_OUPTUT.getLongOpt(),
                CODAHALE_OUT_DEFAULT_FILE_NAME));

        FileUtils.write(new File(path, COMMON_METRICS_FILE_NAME), JsonUtil.valueAsString(fixture, true));
    }

    public static void main(String[] args) throws Exception {
        KafkaServiceMetricsSchemaGenerator generator = new KafkaServiceMetricsSchemaGenerator(args);
        generator.generateFixture();
        generator.generateCommonMetricsFixture();
    }
}

