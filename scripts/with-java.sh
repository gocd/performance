#!/usr/bin/env bash

function use_jdk() {
  if [ ! -f "${HOME}/.jabba/jabba.sh" ]; then
    curl -sL https://github.com/shyiko/jabba/raw/master/install.sh | bash
  fi
  source "${HOME}/.jabba/jabba.sh"
  jabba install "$1=$2"
  jabba use "$1"
}

if [[ -z "${JAVA_VERSION}" ]]; then
  # use the system jvm
  true
elif [ "${JAVA_VERSION}" = "1.10" ]; then
  use_jdk "openjdk@1.10.0-2" "tgz+https://nexus.gocd.io/repository/s3-mirrors/local/jdk/openjdk-10.0.2_linux-x64_bin.tar.gz"
elif [ "${JAVA_VERSION}" = "11" ]; then
  use_jdk "openjdk@1.11.0-28" "tgz+https://nexus.gocd.io/repository/s3-mirrors/local/jdk/openjdk-11-28_linux-x64_bin.tar.gz"
elif [ "${JAVA_VERSION}" = "12" ]; then
  use_jdk "openjdk@1.12.0" "tgz+https://download.java.net/java/GA/jdk12/GPL/openjdk-12_linux-x64_bin.tar.gz"
fi

exec "$@"
