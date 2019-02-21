#!/bin/bash

time=$(date)

tee $PWD/helm_chart/batch-change.json >/dev/null <<EOF 
{
    "Comment": "changed value for the eks perf run on $time",
        "Changes": [
          {
            "Action": "UPSERT",
            "ResourceRecordSet": {
          "Name": "perf-eks-test.gocd.org.",
          "Type": "CNAME",
          "TTL": 300,
          "ResourceRecords": [
              {
                  "Value": "$GOCD_SERVER_LB"
              }
          ]
            }
      }
    ]
}
EOF