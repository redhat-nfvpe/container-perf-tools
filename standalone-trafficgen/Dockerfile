FROM centos:7

ENV TREX_VER "v2.87"

RUN yum -y --enablerepo=extras install epel-release dpdk dpdk-tools \
       		pciutils which \
       		gcc python python-devel \
       		net-tools \
       		tmux gettext
RUN yum install -y python-pip
RUN pip install --no-cache-dir --upgrade "pip < 21.0" \
       && pip install --no-cache-dir --upgrade setuptools wheel \
       && pip install --no-cache-dir grpcio \
       && pip install --no-cache-dir grpcio-tools \
       && pip install --no-cache-dir psutil \
       && mkdir -p /opt/trex \
       && mkdir -p /var/log/tgen \
       && mkdir -p /root/tgen \
       && curl -o /root/tgen/binary-search.py https://raw.githubusercontent.com/atheurer/trafficgen/crucible1/binary-search.py \
       && curl -o /root/tgen/trex_tg_lib.py https://raw.githubusercontent.com/atheurer/trafficgen/crucible1/trex_tg_lib.py \
       && curl -o /root/tgen/trex-txrx.py https://raw.githubusercontent.com/atheurer/trafficgen/crucible1/trex-txrx.py \
       && curl -o /root/tgen/trex-query.py https://raw.githubusercontent.com/atheurer/trafficgen/crucible1/trex-query.py \
       && curl -o /root/tgen/tg_lib.py https://raw.githubusercontent.com/atheurer/trafficgen/crucible1/tg_lib.py \
       && curl -k -o $TREX_VER.tar.gz https://trex-tgn.cisco.com/trex/release/$TREX_VER.tar.gz \
       && tar xzf $TREX_VER.tar.gz -C /opt/trex && ln -sf /opt/trex/${TREX_VER} /opt/trex/current \
       && rm -f $TREX_VER.tar.gz \
       && rm -f /opt/trex/$TREX_VER/trex_client_$TREX_VER.tar.gz \
       && curl -L -k -o /root/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_x86_64 \
       && chmod +x /root/dumb-init \
       && yum clean all && rm -rf /var/cache/yum
COPY server.py rpc.proto trex_cfg.yaml.tmpl /root/tgen/
RUN pushd /root/tgen && python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. rpc.proto && rm rpc.proto && popd
COPY trafficgen_entry.sh /root/
RUN chmod 777 /root/trafficgen_entry.sh /root/tgen/binary-search.py /root/tgen/trex-query.py /root/tgen/trex-txrx.py

ENTRYPOINT ["/root/dumb-init", "--"]
CMD ["/root/trafficgen_entry.sh", "start"]

