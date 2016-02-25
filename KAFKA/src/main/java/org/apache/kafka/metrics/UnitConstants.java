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

public class UnitConstants {
    private UnitConstants() {}

    public static final String partitions = "partitions";
    public static final String replicas = "replicas";
    public static final String controller = "controller";
    public static final String requests = "requests";
    public static final String responses = "responses";
    public static final String messages = "messages";
    public static final String message_batches = "message_batches";
    public static final String bytes = "bytes";
    public static final String segments = "segments";
    public static final String groups = "groups";

    public static final String elections = "elections";
    public static final String expansions = "expansions";
    public static final String shrinks = "shrinks";
    public static final String flushes = "flushes";

    public static final String second = "second";
    public static final String nanoseconds = "nanoseconds";
    public static final String ms = "ms";
    public static final String offset = "offset";
    public static final String percent_idle = "percent_idle";
    public static final String state = "state";

    public static final String fetch_requests = "fetch_requests";
    public static final String fetchRequests = "fetch requests";
}
