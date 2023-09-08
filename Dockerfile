FROM ubi8
USER root
COPY run.sh /root
COPY . /root/container-tools

RUN yum -y install rt-tests stress-ng \
      git which pciutils wget tmux xz \
      diffutils python3 net-tools libtool automake gcc gcc-c++ cmake autoconf \
      unzip python3-six numactl-devel make kernel-devel numactl-libs \
      libibverbs libibverbs-devel rdma-core-devel \
      libibverbs-utils mstflint gettext intel-cmt-cat \
      https://rpmfind.net/linux/epel/8/Everything/x86_64/Packages/l/libmd-1.1.0-1.el8.x86_64.rpm \
      https://rpmfind.net/linux/epel/8/Everything/x86_64/Packages/l/libbsd-0.11.7-2.el8.x86_64.rpm \
      https://rpmfind.net/linux/epel/8/Everything/x86_64/Packages/u/uperf-1.0.7-1.el8.x86_64.rpm \
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
    && wget -O /root/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64 \
    && chmod 777 /root/dumb-init \
    && chmod 777 /root/run.sh
WORKDIR /root
ENTRYPOINT ["/root/dumb-init", "--"]
CMD ["/root/run.sh"]
