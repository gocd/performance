# GoCD Performance tests

This script is used for performance test of GoCD server and agents. 

## Requirements

* Ruby 2.1+
* bundler
* Docker

## Micro Performance

GoCD performance test is executed on the build.gocd.org server since resources needed to deploy, setup and load 1000s of pipelines need bigger infrastructure. For situations where need to run simple micro performance test locally on ones computer there is micro performance setup available in this repo

To start micro performance checkout this repo and run below commands from the repo folder,

This prepares the bundler environment

```
$ bundle install --path=vendor/bundle
```

Micro performance setup is based on docker-compose, ensure `docker` and `docker-compose` are installed and docker engine is running. All scripts are in `micro_performance` folder. 

File `micro_performance/configuration.json` is used for defining the performance test configuration. A Sample content for configuration file 

```
{
    "test_duration": "1800",
    "pipelines": {
        "count": "10"
    },
    "agents": {
        "static":{
            "count": "3"
            }
        },
    "scenarios": [
        {
            "name": "dashboard",
            "url": "api/dashboard",
            "response_code": 200,
            "throughput": "60",
            "thread_count": 10,
            "rampup": 10,
            "duration": 180
        }
    ]
}
```


From the repo checkout folder run,

```
$ bundle exec ruby micro_performance/run.rb
1) Run perf test from scratch
2) Cleanup all components created by performance script(including docker images)
3) Start docker compose and bring up the perf setup
4) Setup Jmeter
5) Sertup pipeline and other entities on already running server
6) Execute perf test on already running server
Enter your choice:
```

Enter your choice according to the purpose. Selecting `1` will run from scrath - Setup separate containers for `GoCD Server`, `Static Agents`, `Git Repos`, `Postgres DB` and `cAdvisor`(for docker container monitoring). Then will create pipelines and other entities as defined in the `micro_performance/configuration.json`(currently only pipelines are supported). Then setup Jmeter and run the scenarios as defined in the file `micro_performance/configuration.json`

Jmeter reports will be stored in `reports` folder for each `scenario` name. 

While performance setup is running cAdvisor can be accessed at `http://localhost:8080`. cAdvisor will help in monitoring CPU and Memory usage of the containers - https://github.com/google/cadvisor

cAdvisor can be extended to store the performance metrics to influxDB, more on that here - https://github.com/google/cadvisor/blob/master/docs/storage/influxdb.md



## License

```plain
Copyright 2019 ThoughtWorks, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
