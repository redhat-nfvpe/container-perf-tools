FROM fedora:42

# Build arguments
ARG COMMIT_SHA=unknown
ARG BUILD_DATE
ARG VERSION

# Metadata labels following OCI image specification
LABEL org.opencontainers.image.title="stress-ng performance testing container"
LABEL org.opencontainers.image.description="Container for running stress-ng system stress testing"
LABEL org.opencontainers.image.version=${VERSION}
LABEL org.opencontainers.image.revision=${COMMIT_SHA}
LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.authors="Container Performance Tools Team"
LABEL org.opencontainers.image.url="https://github.com/redhat-nfvpe/container-perf-tools"
LABEL org.opencontainers.image.documentation="https://github.com/redhat-nfvpe/container-perf-tools/blob/main/README.md"
LABEL org.opencontainers.image.source="https://github.com/redhat-nfvpe/container-perf-tools"
LABEL org.opencontainers.image.licenses="GPL-2.0"
LABEL org.opencontainers.image.vendor="Container Performance Tools Team"

# Install packages and clean up in single layer for smaller image size
USER root
COPY stress-ng/cmd.sh /root
COPY common-libs /root/common-libs
RUN yum -y update \
    && yum -y install \
        stress-ng \
        dumb-init \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && chmod +x /root/cmd.sh

# Set working directory
WORKDIR /root

# Use dumb-init to handle signals properly
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Default command
CMD ["/root/cmd.sh"]
