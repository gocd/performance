FROM centos

    ENV RUBY_DIR /ruby
    ENV RUBY_VERSION 2.3.1
    ENV RUBY_INSTALL $RUBY_DIR/$RUBY_VERSION

    RUN rpm -Uvh \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
        yum update -y && \
        yum install -y make which wget tar \
        gcc patch readline-devel zlib-devel git git-daemon    \
        libyaml-devel libffi-devel openssl-devel \
        gdbm-devel ncurses-devel libxml-devel bzip2 gcc-c++

    RUN cd /usr/src && \
        git clone https://github.com/sstephenson/ruby-build.git && \
        ./ruby-build/install.sh && \
        mkdir -p $RUBY_INSTALL && \
        /usr/local/bin/ruby-build $RUBY_VERSION $RUBY_INSTALL && \
        rm -rf /usr/src/ruby-build

    ENV PATH $RUBY_INSTALL/bin:$PATH

    RUN gem install bundler
    RUN git config --global user.name "Perf Tester"
    RUN git config --global user.email "perf-tester@test.com"
    
    

    ADD gocd-test-repo-docker-entrypoint.sh /

    ENTRYPOINT ["/gocd-test-repo-docker-entrypoint.sh"]