set -e

for i in {1..$TOTAL_PIPELINES}
do
  curl 'http://perfserver:8153/go/api/admin/pipelines' \
      -u 'admin:badger' \
      -H 'Accept: application/vnd.go.cd+json' \
      -H 'Content-Type: application/json' \
      -X POST -d '{ "group": "performance",
                    "pipeline": {
                    "label_template": "${COUNT}",
                    "lock_behavior": "lockOnFailure",
                    "name": "perf_pipeline_$i",
                    "template": null,
                    "materials": [
                      {
                        "type": "git",
                        "attributes": {
                          "url": "git://agents/git-repo-$i",
                          "destination": "dest",
                          "filter": null,
                          "invert_filter": false,
                          "name": null,
                          "auto_update": true,
                          "branch": "master",
                          "submodule_folder": null,
                          "shallow_clone": true
                        }
                      }
                    ],
                    "stages": [
                      {
                        "name": "defaultStage",
                        "fetch_materials": true,
                        "clean_working_directory": false,
                        "never_cleanup_artifacts": false,
                        "approval": {
                          "type": "success",
                          "authorization": {
                            "roles": [],
                            "users": []
                          }
                        },
                        "environment_variables": [],
                        "jobs": [
                          {
                            "name": "defaultJob",
                            "run_instance_count": null,
                            "timeout": 0,
                            "environment_variables": [],
                            "resources": [],
                            "tasks": [
                              {
                                "type": "exec",
                                "attributes": {
                                  "run_if": [
                                    "passed"
                                  ],
                                  "command": "ls",
                                  "working_directory": null
                                }
                              }
                            ]
                          }
                        ]
                      }
                    ]
                }
              }'
done
