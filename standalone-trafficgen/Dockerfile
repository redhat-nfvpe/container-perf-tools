FROM centos:7

ENV TREX_VER "v2.82"

RUN yum -y --enablerepo=extras install epel-release dpdk dpdk-tools \
       		pciutils which \
       		gcc python python-devel \
       		net-tools \
       		tmux
RUN yum install -y python-pip
RUN pip install --upgrade pip \
       && pip install --upgrade setuptools wheel \
       && pip install grpcio \
       && pip install grpcio-tools \
       && pip install psutil \
       && mkdir -p /opt/trex \
       && mkdir -p /var/log/tgen \
       && mkdir -p /root/tgen \
       && curl -o /root/tgen/binary-search.py https://raw.githubusercontent.com/atheurer/trafficgen/master/binary-search.py \
       && curl -o /root/tgen/trex_tg_lib.py https://raw.githubusercontent.com/atheurer/trafficgen/master/trex_tg_lib.py \
       && curl -o /root/tgen/trex-txrx.py https://raw.githubusercontent.com/atheurer/trafficgen/master/trex-txrx.py \
       && curl -o /root/tgen/trex-query.py https://raw.githubusercontent.com/atheurer/trafficgen/master/trex-query.py \
       && curl -o /root/tgen/tg_lib.py https://raw.githubusercontent.com/atheurer/trafficgen/master/tg_lib.py \
       && curl -k -o $TREX_VER.tar.gz https://trex-tgn.cisco.com/trex/release/$TREX_VER.tar.gz \
       && tar xzf $TREX_VER.tar.gz -C /opt/trex && ln -sf /opt/trex/${TREX_VER} /opt/trex/current \
       && rm -f $TREX_VER.tar.gz \
       && rm -f /opt/trex/$TREX_VER/trex_client_$TREX_VER.tar.gz \
       && curl -L -k -o /root/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_x86_64 \
       && chmod +x /root/dumb-init \
       && yum clean all && rm -rf /var/cache/yum
COPY launch-trex.sh server.py rpc_pb2.py rpc_pb2_grpc.py /root/tgen/
COPY trafficgen_entry.sh /root/
RUN chmod 777 /root/trafficgen_entry.sh /root/tgen/launch-trex.sh /root/tgen/binary-search.py /root/tgen/trex-query.py /root/tgen/trex-txrx.py

ENTRYPOINT ["/root/dumb-init", "--"]
CMD ["/root/trafficgen_entry.sh", "start"]

