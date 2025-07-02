FROM fedora:42

# Build arguments
ARG COMMIT_SHA=unknown
ARG BUILD_DATE
ARG VERSION
ARG ARCH

# Metadata labels following OCI image specification
LABEL org.opencontainers.image.title="dpdk-testpmd performance testing container"
LABEL org.opencontainers.image.description="Container for running dpdk-testpmd"
LABEL org.opencontainers.image.version=${VERSION}
LABEL org.opencontainers.image.revision=${COMMIT_SHA}
LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.authors="Container Performance Tools Team"
LABEL org.opencontainers.image.url="https://github.com/redhat-nfvpe/container-perf-tools"
LABEL org.opencontainers.image.documentation="https://github.com/redhat-nfvpe/container-perf-tools/blob/main/README.md"
LABEL org.opencontainers.image.source="https://github.com/redhat-nfvpe/container-perf-tools"
LABEL org.opencontainers.image.licenses="GPL-2.0"
LABEL org.opencontainers.image.vendor="Container Performance Tools Team"

USER root
COPY dpdk-testpmd/terminate.sh /usr/bin/terminate
COPY dpdk-testpmd/run.sh /usr/bin/run.sh
COPY dpdk-testpmd/cmd.sh /root

RUN INSTALL_PKGS="bsdtar \
  findutils \
  util-linux \
  numactl \
  numactl-devel \
  tmux \
  tar \
  ethtool \
  patch \
  which \
  procps-ng \
  readline-devel \
  perf \
  pciutils \
  kmod \
  iproute \
  rsync \
  libatomic \
  xz \
  libibverbs" && \
  yum install -y $INSTALL_PKGS && \
  rpm -V $INSTALL_PKGS && \
  yum -y clean all

# Install a specific version of the dpdk package
ARG BASEURL="https://kojipkgs.fedoraproject.org/packages/dpdk"
ARG BASEVERSION="24.11.1"
ARG BUILDNUMBER="2.fc42"

ARG DPDK_RPM_URL=${BASEURL}/${BASEVERSION}/${BUILDNUMBER}/${ARCH}
ARG DPDK_RPM=dpdk-${BASEVERSION}-${BUILDNUMBER}.${ARCH}.rpm
ARG DPDK_DEVEL_RPM=dpdk-tools-${BASEVERSION}-${BUILDNUMBER}.${ARCH}.rpm
RUN curl -k -o /opt/${DPDK_RPM} ${DPDK_RPM_URL}/${DPDK_RPM}
RUN curl -k -o /opt/${DPDK_DEVEL_RPM} ${DPDK_RPM_URL}/${DPDK_DEVEL_RPM}
RUN dnf install -y /opt/$DPDK_RPM
RUN dnf install -y /opt/$DPDK_DEVEL_RPM

# Save the dpdk version as an env variable
ENV DPDK_VERSION=dpdk-$BASEVERSION-$BUILDNUMBER-$ARCH

# Set working directory
WORKDIR /root

ENTRYPOINT ["/usr/bin/run.sh"]
