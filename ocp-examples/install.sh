#!/usr/bin/env bash

set -euo pipefail
SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`

rm -rf ~/perf-test
cp -r ${SCRIPTPATH}/trafficgen-testpmd ~/perf-test
cp ${SCRIPTPATH}/cyclictest/pod_cyclictest.yaml ~/perf-test/
pushd ${SCRIPTPATH}/../standalone-testpmd/cmd/client-example
go build && cp client-example ~/perf-test/testpmd-client
popd
cp ${SCRIPTPATH}/../standalone-trafficgen/client.py ~/perf-test/


