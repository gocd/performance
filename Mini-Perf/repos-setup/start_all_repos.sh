#!/bin/bash

set -e

git config --global user.email "you@example.com"

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
    echo "add text to file $i" > file.txt
    git add .; git commit -m "Commit number $i"
    cd -
  done
  sleep 900
  COUNTER=$((COUNTER + 900))
done
