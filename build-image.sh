#!/usr/bin/env bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -xe

SELF_DIR="$(cd "$(dirname "$0")"; pwd)"

source "${SELF_DIR}/.env"

BUILD_CMD="docker build"

if [ $BUILDX ]; then
  echo "Using buildx to build cross-platform images"
  BUILD_CMD="docker buildx build --platform=linux/amd64,linux/arm64 --push"
fi

mkdir -p base-ubuntu-2204/download
if [ $(uname -m) = "aarch64" ]; then JDK8_TAR_NAME=zulu${ZULU8_VERSION}-ca-jdk${JDK8_VERSION}-linux_aarch64; else JDK8_TAR_NAME=zulu${ZULU8_VERSION}-ca-jdk${JDK8_VERSION}-linux_x64; fi
if [ $(uname -m) = "aarch64" ]; then JDK17_TAR_NAME=zulu${ZULU17_VERSION}-ca-jdk${JDK17_VERSION}-linux_aarch64; else JDK17_TAR_NAME=zulu${ZULU17_VERSION}-ca-jdk${JDK17_VERSION}-linux_x64; fi
cp download/${JDK8_TAR_NAME}.tar.gz base-ubuntu-2204/download/${JDK8_TAR_NAME}.tar.gz
cp download/${JDK17_TAR_NAME}.tar.gz base-ubuntu-2204/download/${JDK17_TAR_NAME}.tar.gz
${BUILD_CMD} \
  --file "${SELF_DIR}/base-ubuntu-2204/Dockerfile" \
  --build-arg JDK8_TAR_NAME=${JDK8_TAR_NAME} \
  --build-arg JDK17_TAR_NAME=${JDK17_TAR_NAME} \
  --tag hadoop-testing/base-ubuntu-2204:${PROJECT_VERSION} \
  "${SELF_DIR}/base-ubuntu-2204" $@

${BUILD_CMD} \
  --build-arg PROJECT_VERSION=${PROJECT_VERSION} \
  --file "${SELF_DIR}/kdc/Dockerfile" \
  --tag hadoop-testing/kdc:${PROJECT_VERSION} \
  "${SELF_DIR}/kdc" $@

${BUILD_CMD} \
  --file "${SELF_DIR}/mysql/Dockerfile" \
  --tag hadoop-testing/mysql:${PROJECT_VERSION} \
  "${SELF_DIR}/mysql" $@

function build_hadoop_master_image() {
  local INDEX=$1
  mkdir -p hadoop-master${INDEX}/download
  cp download/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz hadoop-master${INDEX}/download/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz
  cp download/hadoop-${HADOOP_VERSION}.tar.gz hadoop-master${INDEX}/download/hadoop-${HADOOP_VERSION}.tar.gz
  cp download/apache-hive-${HIVE_VERSION}-bin.tar.gz hadoop-master${INDEX}/download/apache-hive-${HIVE_VERSION}-bin.tar.gz
  cp download/spark-${SPARK_VERSION}-bin-hadoop3.tgz hadoop-master${INDEX}/download/spark-${SPARK_VERSION}-bin-hadoop3.tgz
  cp download/apache-kyuubi-${KYUUBI_VERSION}-bin.tgz hadoop-master${INDEX}/download/apache-kyuubi-${KYUUBI_VERSION}-bin.tgz
  cp download/kyuubi-spark-connector-tpch_${SCALA_BINARY_VERSION}-${KYUUBI_VERSION}.jar hadoop-master${INDEX}/download/kyuubi-spark-connector-tpch_${SCALA_BINARY_VERSION}-${KYUUBI_VERSION}.jar
  cp download/kyuubi-spark-connector-tpcds_${SCALA_BINARY_VERSION}-${KYUUBI_VERSION}.jar hadoop-master${INDEX}/download/kyuubi-spark-connector-tpcds_${SCALA_BINARY_VERSION}-${KYUUBI_VERSION}.jar
  cp download/mysql-connector-j-${MYSQL_JDBC_VERSION}.jar hadoop-master${INDEX}/download/mysql-connector-j-${MYSQL_JDBC_VERSION}.jar
  cp download/log4j2-appender-nodep-${LOKI_APPENDER_VERSION}.jar hadoop-master${INDEX}/download/log4j2-appender-nodep-${LOKI_APPENDER_VERSION}.jar
  ${BUILD_CMD} \
    --build-arg PROJECT_VERSION=${PROJECT_VERSION} \
    --build-arg ZOOKEEPER_VERSION=${ZOOKEEPER_VERSION} \
    --build-arg HADOOP_VERSION=${HADOOP_VERSION} \
    --build-arg HIVE_VERSION=${HIVE_VERSION} \
    --build-arg SPARK_VERSION=${SPARK_VERSION} \
    --build-arg SPARK_BINARY_VERSION=${SPARK_BINARY_VERSION} \
    --build-arg SCALA_BINARY_VERSION=${SCALA_BINARY_VERSION} \
    --build-arg KYUUBI_VERSION=${KYUUBI_VERSION} \
    --build-arg MYSQL_JDBC_VERSION=${MYSQL_JDBC_VERSION} \
    --build-arg LOKI_APPENDER_VERSION=${LOKI_APPENDER_VERSION} \
    --file "${SELF_DIR}/hadoop-master${INDEX}/Dockerfile" \
    --tag hadoop-testing/hadoop-master${INDEX}:${PROJECT_VERSION} \
    "${SELF_DIR}/hadoop-master${INDEX}" $2
}

build_hadoop_master_image 1 "$@"

function build_hadoop_worker_image() {
  local INDEX=$1
  mkdir -p hadoop-worker${INDEX}/download
  cp download/hadoop-${HADOOP_VERSION}.tar.gz hadoop-worker${INDEX}/download/hadoop-${HADOOP_VERSION}.tar.gz
  cp download/spark-${SPARK_VERSION}-bin-hadoop3.tgz hadoop-worker${INDEX}/download/spark-${SPARK_VERSION}-bin-hadoop3.tgz
  tar -xzf hadoop-worker${INDEX}/download/spark-${SPARK_VERSION}-bin-hadoop3.tgz -C hadoop-worker${INDEX}/download spark-${SPARK_VERSION}-bin-hadoop3/yarn
  ${BUILD_CMD} \
    --build-arg PROJECT_VERSION=${PROJECT_VERSION} \
    --build-arg HADOOP_VERSION=${HADOOP_VERSION} \
    --build-arg SPARK_VERSION=${SPARK_VERSION} \
    --file "${SELF_DIR}/hadoop-worker${INDEX}/Dockerfile" \
    --tag hadoop-testing/hadoop-worker${INDEX}:${PROJECT_VERSION} \
    "${SELF_DIR}/hadoop-worker${INDEX}" $2
}

build_hadoop_worker_image 1 "$@"
build_hadoop_worker_image 2 "$@"
build_hadoop_worker_image 3 "$@"