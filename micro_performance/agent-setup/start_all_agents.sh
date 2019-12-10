#!/bin/bash

set -e

mkdir -p /home/go-agent-0
curl -k -u admin:badger https://perfserver:8154/go/admin/agent.jar -o /home/go-agent-0/agent.jar
curl -k -u admin:badger https://perfserver:8154/go/admin/tfs-impl.jar -o /home/go-agent-0/tfs-impl.jar
curl -k -u admin:badger https://perfserver:8154/go/admin/agent-plugins.zip -o /home/go-agent-0/agent-plugins.zip

mkdir -p /var/go
curl https://download.java.net/openjdk/jdk11/ri/openjdk-11+28_linux-x64_bin.tar.gz -o /var/go/openjdk-11+28_linux-x64_bin.tar.gz
tar -xvf /var/go/openjdk-11+28_linux-x64_bin.tar.gz -C /var/go/
export PATH=/var/go/jdk-11/bin:$PATH

for i in $(seq 1 $TOTAL_AGENTS)
do
  mkdir -p /home/go-agent-$i/config
  cp -r /home/go-agent-0/agent.jar /home/go-agent-$i/agent.jar
  cp -r /home/go-agent-0/tfs-impl.jar /home/go-agent-$i/tfs-impl.jar
  cp -r /home/go-agent-0/agent-plugins.zip /home/go-agent-$i/agent-plugins.zip
  cp /godata/autoregister.properties /home/go-agent-$i/config/

  chmod -R 0755 /home/go-agent-$i/

  cd /home/go-agent-$i/
  java -jar /home/go-agent-$i/agent.jar -serverUrl https://perfserver:8154/go > agent-$i-startup.log 2>&1 &
  sleep 20
  cd -
done

sleep $PERF_TEST_DURATION
