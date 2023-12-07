FROM fedora:39
USER root
COPY run.sh /root
COPY . /root/container-tools

RUN yum -y install realtime-tests stress-ng dumb-init \
      git which pciutils wget tmux xz \
      diffutils python3 net-tools libtool automake gcc gcc-c++ cmake autoconf \
      unzip python3-six numactl-devel make kernel-devel numactl-libs \
      libibverbs libibverbs-devel rdma-core-devel \
      libibverbs-utils mstflint gettext intel-cmt-cat \
      libmd libbsd uperf \
      libaio-devel libattr-devel libcap-devel libgcrypt-devel \
    && curl -L -o dpdk.tar.xz https://fast.dpdk.org/rel/dpdk-20.08.tar.xz \
    && mkdir -p /opt/dpdk && tar -xf dpdk.tar.xz -C /opt/dpdk && rm -rf dpdk.tar.xz \
    && pushd /opt/dpdk/dpdk* && sed -i 's/\(CONFIG_RTE_LIBRTE_MLX5_PMD=\)n/\1y/g' config/common_base \
    && make install T=x86_64-native-linuxapp-gcc DESTDIR=install MAKE_PAUSE=n \
    && install -t /usr/local/bin install/sbin/dpdk-devbind \
    && install -t /usr/local/bin install/bin/testpmd \
    && popd && rm -rf /opt/dpdk \
    && ln -s $(which python3) /usr/local/bin/python \
    && yum clean all && rm -rf /var/cache/yum \
    && chmod 777 /root/run.sh
WORKDIR /root
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/root/run.sh"]
