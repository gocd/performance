#!/bin/bash

set -e

git config --global user.email "perf@test.com"

for i in $(seq 1 $TOTAL_PIPELINES)
do
  mkdir -p /home/git-repo-$i

  cd /home/git-repo-$i/
  git init; touch ".git/git-daemon-export-ok"; touch file.txt; git add .; git commit -m "Initial commit to git repo $i" --author 'foo <foo@bar.com>'
  cd -
done

git daemon --base-path=/home/ --detach --syslog --export-all

COUNTER=0
while [ "$COUNTER" -lt "$PERF_TEST_DURATION" ]
do
  for i in $(seq 1 $TOTAL_PIPELINES)
  do
    cd /home/git-repo-$i/
    echo "Making changes after sleeping for $COUNTER seconds" >> file.txt
    current_time=`date +"%s"`
    git add .; git commit -m "Commit time $current_time" --author 'Perf <perf@test.com>'; git gc;
    cd -
  done
  sleep 300
  COUNTER=$((COUNTER + 300))
done
