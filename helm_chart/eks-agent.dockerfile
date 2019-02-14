FROM gocd/gocd-agent-centos-7:v19.1.0

    RUN yum install --assumeyes centos-release-scl # for ruby-2.3
    RUN yum install --assumeyes libxml2-devel libxslt-devel zlib-devel bzip2-devel glibc-devel autoconf bison flex kernel-devel libcurl-devel make cmake openssl-devel \
    libffi-devel readline-devel libedit-devel bash devtoolset-6-gcc devtoolset-6-gcc-c++
    
    RUN echo -e 'source /opt/rh/devtoolset-6/enable \nexport PATH=$PATH:/opt/rh/devtoolset-6/root/usr/bin \nexport X_SCLS=devtoolset-6' >> /etc/profile.d/scl-gcc-6.sh
    RUN yum install --assumeyes rh-ruby23 rh-ruby23-ruby-devel rh-ruby23-rubygem-bundler rh-ruby23-ruby-irb rh-ruby23-rubygem-rake rh-ruby23-rubygem-psych libffi-devel openssl
    RUN echo -e 'source /opt/rh/rh-ruby23/enable \nexport PATH=$PATH:/opt/rh/rh-ruby23/root/usr/local/bin \nexport X_SCLS="rh-ruby23 $X_SCLS"' >> /etc/profile.d/scl-rh-ruby23.sh
    
    RUN echo -e '[kubernetes] \nname=Kubernetes \nbaseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64 \nenabled=1 \ngpgcheck=1 \nrepo_gpgcheck=1 \ngpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg '>>/etc/yum.repos.d/kubernetes.repo

    RUN yum install -y kubectl

    RUN yum install -y epel-release

    RUN yum install -y python-pip

    RUN pip install awscli

    RUN curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator

    RUN chmod +x ./aws-iam-authenticator

    RUN mv aws-iam-authenticator /usr/local/bin

    RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

    RUN mv /tmp/eksctl /usr/local/bin

    Run curl --silent https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh

    RUN chmod 700 get_helm.sh

    RUN ./get_helm.sh

    
