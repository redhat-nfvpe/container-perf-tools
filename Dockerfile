FROM centos:8
USER root
COPY run.sh /root
COPY rt.repo /etc/yum.repos.d/
RUN yum -y install rt-tests rteval \
    && rm -rf /etc/yum.repos.d/rt.repo \
    && yum -y --enablerepo=extras install epel-release git which pciutils wget tmux \
      python3 net-tools libtool automake gcc gcc-c++ cmake autoconf \
      unzip python3-six numactl-devel make kernel-devel numactl-libs \
      libibverbs libibverbs-devel rdma-core-devel \
      libibverbs-utils mstflint dpdk dpdk-tools gettext \
    && yum install -y libaio-devel libattr-devel libbsd-devel libcap-devel libgcrypt-devel \
    && yum -y --enablerepo=epel-testing install uperf \
    && git clone https://github.com/ColinIanKing/stress-ng.git \
    && cd stress-ng && make clean && make \
    && install -D stress-ng /usr/local/bin/stress-ng \
    && cd .. && rm -rf stress-ng \
    && yum clean all && rm -rf /var/cache/yum \
    && wget -O /root/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64 \
    && chmod 777 /root/dumb-init \
    && chmod 777 /root/run.sh
WORKDIR /root
ENTRYPOINT ["/root/dumb-init", "--"]
CMD ["/root/run.sh"]
