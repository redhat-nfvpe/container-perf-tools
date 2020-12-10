FROM centos:8
USER root
COPY run.sh /root

# Uncomment for GIT_URL="false" 
RUN curl -OL https://github.com/redhat-nfvpe/container-perf-tools/archive/master.zip \
&& unzip master.zip && rm -f master.zip \
&& mv container-perf-tools-master /root/container-tools

RUN yum -y install https://www.rpmfind.net/linux/centos/8-stream/AppStream/x86_64/os/Packages/rt-tests-1.8-11.el8.x86_64.rpm \
    && yum -y --enablerepo=extras install epel-release git which pciutils wget tmux \
      diffutils python3 net-tools libtool automake gcc gcc-c++ cmake autoconf \
      unzip python3-six numactl-devel make kernel-devel numactl-libs \
      libibverbs libibverbs-devel rdma-core-devel \
      libibverbs-utils mstflint gettext \
    && yum install -y libaio-devel libattr-devel libbsd-devel libcap-devel libgcrypt-devel \
    && yum -y --enablerepo=epel-testing install uperf  stress-ng \
    && curl -L -o dpdk.tar.xz https://fast.dpdk.org/rel/dpdk-20.08.tar.xz \
    && mkdir -p /opt/dpdk && tar -xf dpdk.tar.xz -C /opt/dpdk && rm -rf dpdk.tar.xz \
    && pushd /opt/dpdk/dpdk* && sed -i 's/\(CONFIG_RTE_LIBRTE_MLX5_PMD=\)n/\1y/g' config/common_base \
    && make install T=x86_64-native-linuxapp-gcc DESTDIR=install MAKE_PAUSE=n \
    && install -t /usr/local/bin install/sbin/dpdk-devbind \
    && install -t /usr/local/bin install/bin/testpmd \
    && popd && rm -rf /opt/dpdk \
    && ln -s $(which python3) /usr/local/bin/python \
    && yum clean all && rm -rf /var/cache/yum \
    && wget -O /root/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64 \
    && chmod 777 /root/dumb-init \
    && chmod 777 /root/run.sh
WORKDIR /root
ENTRYPOINT ["/root/dumb-init", "--"]
CMD ["/root/run.sh"]
