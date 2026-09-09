# Latency Testing Tools for OpenShift

Measure system latency and DPDK network throughput\
Verify the system's CPU isolation on isolated cores\
Accept configuration via YAML and environment variables\
Output results to container logs

## Tools
RT kernel scheduler latency: cyclictest, rtla timerlat\
OS-level latency detection: oslat, rtla osnoise\
Hardware/firmware latency: hwlatdetect, rtla hwnoise\
CPU stress testing: stress-ng\
Network throughput: testpmd, trafficgen

Each tool has sample YAML in sample-yamls directory.
Pre-built images are available at quay.io.
Tools also run directly under podman.

Use cases: RT debugging, DPDK benchmarking, stress testing,
CI/CD regression testing.
