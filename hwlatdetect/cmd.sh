#!/bin/bash

# env vars:
#   RUNTIME_SECONDS (default 10)
#   manual (default 'n', choice y/n, don't run test - for debug purposes)
#   delay   (default 0, specify how many second to delay before test start)
#   THRESHOLD (no default, only record hardware latencies above THRESHOLD (in usec))
#   EXTRA_ARGS (default "", will be passed directly to oslat command)

source common-libs/functions.sh

RUNTIME_SECONDS=${RUNTIME_SECONDS:-10}

echo "############# dumping env ###########"
env
echo "#####################################"

echo " "
echo "########## container info ###########"
echo "/proc/cmdline:"
cat /proc/cmdline
echo "#####################################"

uname=`uname -nr`
echo "$uname"
rpm -q rt-tests

for cmd in hwlatdetect; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed.  Aborting"; exit 1; }
done

extra_args=""
if [ -n "$THRESHOLD" ]; then
    extra_args="--threshold=$THRESHOLD"
fi

command="hwlatdetect --duration ${RUNTIME_SECONDS} ${extra_args} --watch ${EXTRA_ARGS}"

echo "cmd to run: ${command}"

if [ "${manual:-n}" == "y" ]; then
	sleep infinity
fi

if [ "${delay:-0}" != "0" ]; then
	echo "sleep ${delay} before test"
	sleep ${delay}
fi

$command

sleep infinity
