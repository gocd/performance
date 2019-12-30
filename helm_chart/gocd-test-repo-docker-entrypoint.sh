#!/bin/bash

# Copyright 2019 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 111; }
try() { echo "$ $@" 1>&2; "$@" || die "cannot $*"; }
 
## Clone the performance repo

git clone -b $PERF_REPO_BRANCH $PERF_REPO_URL

if [ -e "${PERFORMANCE_REPO_DIRECTORY}" ];then

    cd "${PERFORMANCE_REPO_DIRECTORY}"
    bundle install --path vendor/bundle
    bundle exec rake git:daemon:start GIT_ROOT="${GIT_ROOT}"
    ## Create Pipelines in Config Repo throught rake task
    bundle exec rake pipeline:create_pipeline_in_config_repo GIT_ROOT="${GIT_ROOT}"

fi

yell "Running custom scripts in /docker-entrypoint.d/ ..."

# to prevent expansion to literal string `/docker-entrypoint.d/*` when there is nothing matching the glob
shopt -s nullglob

for file in /docker-entrypoint.d/*; do
    if [ -f "$file" ] && [ -x "$file" ]; then
    try "$file"
    else
    yell "Ignoring $file, it is either not a file or is not executable"
    fi
done

bundle exec rake performance:git:update

try exec "$@"