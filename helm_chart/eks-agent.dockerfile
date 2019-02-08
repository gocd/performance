FROM gocd/gocd-agent-centos-7:v19.1.0

    RUN yum install --assumeyes centos-release-scl # for ruby-2.3
    RUN yum install --assumeyes ruby ruby-devel rubygem-bundler ruby-irb rubygem-rake rubygem-psych libffi-devel

    RUN echo -e '[kubernetes] \nname=Kubernetes \nbaseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64 \nenabled=1 \ngpgcheck=1 \nrepo_gpgcheck=1 \ngpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg '>>/etc/yum.repos.d/kubernetes.repo

    RUN yum install -y kubectl

    RUN yum install -y epel-release

    RUN yum install -y python-pip

    RUN pip install awscli

    RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

    RUN mv /tmp/eksctl /usr/local/bin

    
