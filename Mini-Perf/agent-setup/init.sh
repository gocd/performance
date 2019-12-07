#!/bin/bash


yum install -y git git-daemon

count=0
while [ "$count" -lt "60" -a "$(nc -zv perfserver 8153 2>/dev/null; echo $?)" -ne "0" ]; do
  [[ "$((count % 10))" = "0" ]] && echo "Waiting for perf Go Server to be up ..."
  sleep 2;
  count=$((count + 1))
done

# start agents as much as needed

bash -x /godata/start_all_agents.sh
