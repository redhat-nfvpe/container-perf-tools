#!/bin/bash

# env vars:
#   RUNTIME_SECONDS (default 10)
#   manual (default 'n', choice y/n, don't run test - for debug purposes)
#   delay   (default 0, specify how many second to delay before test start)
#   THRESHOLD (no default, only record hardware latencies above THRESHOLD (in usec))
#   ALL_CPUS (default 'n', choice y/n, test all online CPUs)
#   EXTRA_ARGS (default "", will be passed directly to hwlatdetect command)
#   PAUSE (default 'y', choice y/n, pause after run)

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
rpm -q realtime-tests

for cmd in hwlatdetect; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed.  Aborting"; exit 1; }
done

extra_args=""
if [ -n "$THRESHOLD" ]; then
    extra_args="--threshold=$THRESHOLD"
fi

if [ "${ALL_CPUS:-n}" != "y" ]; then
    cpulist=$(get_allowed_cpuset)
    if [ -z "$cpulist" ]; then
        echo >&2 "Unable to determine CPU list. Aborting"
        exit 1
    fi
    extra_args+=" --cpu-list ${cpulist}"
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

tracing_dir=/sys/kernel/debug/tracing
if [ ! -e "$tracing_dir/tracing_cpumask" ]; then
    mount -t debugfs none /sys/kernel/debug || exit 1
fi
saved_mask=$(cat "$tracing_dir/tracing_cpumask") || exit 1
echo "Saved tracing_cpumask: $saved_mask"

restore_cpumask() {
    printf '%s\n' "$saved_mask" > "$tracing_dir/tracing_cpumask" || {
        echo >&2 "Failed to restore tracing_cpumask: $saved_mask"
        return 1
    }
    echo "Restored tracing_cpumask: $saved_mask"
}
trap restore_cpumask EXIT

if [ "${ALL_CPUS:-n}" == "y" ]; then
    all_mask=$(cpulist_to_mask "$(cat /sys/devices/system/cpu/online)") || exit 1
    echo "Setting tracing_cpumask for all online CPUs: $all_mask"
    printf '%s\n' "$all_mask" > "$tracing_dir/tracing_cpumask" || exit 1
fi

$command
rc=$?
if restore_cpumask; then
    trap - EXIT
else
    rc=1
fi

[[ "${PAUSE:-y}" == "y" ]] && sleep infinity

exit $rc
