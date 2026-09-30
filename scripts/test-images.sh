#!/bin/bash

# Smoke test for container-perf-tools images
# Runs each tool as a pod, monitors logs, validates output

set -uo pipefail

d=$(dirname "$(readlink --canonicalize "$0")")/..
timeout=${TIMEOUT:-120}
pass=0
fail=0

show_pod_debug() {
    local name=$1 log=$2
    {
        echo "Pod $name status and recent events:"
        timeout 10 oc get pod "$name" -o wide
        timeout 10 oc describe pod "$name" | tail --lines=80
    } 2>&1 | tee -a "$log"
}

watch_logs() {
    local name=$1 pattern=$2 log=$3
    local pid log_rc rc
    timeout "$timeout" oc logs --follow "pod/$name" >> "$log" &
    pid=$!
    tail --follow --pid=$pid --lines=+1 "$log" |
        while IFS= read -r line; do
            [[ $line =~ Aborting|Traceback|^Error:|ValueError|Failed.to.enable ]] && kill $pid 2>/dev/null && break
            [[ $line =~ $pattern ]] && kill $pid 2>/dev/null && break
        done
    wait $pid 2>/dev/null
    log_rc=$?
    if [[ $log_rc -eq 124 ]]; then
        echo "Timed out after ${timeout}s waiting for '$pattern' in $name logs" | tee -a "$log"
        show_pod_debug "$name" "$log"
    fi

    grep --quiet --ignore-case "$pattern" "$log"
    rc=$?
    [[ $log_rc -eq 124 ]] && rc=124
    return "$rc"
}

check_hwlat() {
    local name=$1 scope=$2 log=$3 rc=0
    local reported_cpus=$(awk '$1 == "CPU" && $2 == "list:" { print $3 }' "$log")
    local saved=$(awk '$1 == "Saved" && $2 == "tracing_cpumask:" { print $3; exit }' "$log")
    if [[ ! $saved ]]; then
        echo "No tracing mask snapshot in $log; check the deployed hwlatdetect image"
        return 1
    fi
    sleep 1
    local current=$(oc exec "pod/$name" -- cat /sys/kernel/debug/tracing/tracing_cpumask)
    if [[ ! $saved || $current != "$saved" ]]; then
        echo "Tracing CPU mask was not restored: saved=$saved current=$current"
        rc=1
    fi
    if [[ $scope == pod ]]; then
        local expected_cpus=$(oc exec "pod/$name" -- cat /proc/self/status | awk '$1 == "Cpus_allowed_list:" { print $2 }')
        if [[ ! $expected_cpus || $reported_cpus != "$expected_cpus" ]]; then
            echo "Expected pod CPU list: $expected_cpus"
            rc=1
        fi
    else
        if [[ $reported_cpus != None ]]; then
            echo "Expected CPU list: None for ALL_CPUS=y"
            rc=1
        fi
        if ! grep --quiet '^Setting tracing_cpumask for all online CPUs: [0-9a-f][0-9a-f,]*$' "$log"; then
            echo "ALL_CPUS=y did not set the all-CPU tracing mask"
            rc=1
        fi
    fi
    return "$rc"
}

run_test() {
    local name=$1 pattern=$2
    shift 2
    local cpu_scope=""
    if [[ ${1:-} == pod || ${1:-} == all ]]; then
        cpu_scope=$1
        shift
    fi
    local log=$name${cpu_scope:+-$cpu_scope}.log

    oc delete pod "$name" --ignore-not-found --wait &>/dev/null || true
    sed "${image_opts[@]}" "$@" "$d/sample-yamls/pod_${name//-/_}.yaml" | oc apply --filename - > "$log" 2>&1
    if ! oc wait --for=condition=Ready --timeout=3m pod "$name" >/dev/null; then
        echo "Pod $name did not become Ready within 3m" | tee -a "$log"
        show_pod_debug "$name" "$log"
    fi

    local rc
    watch_logs "$name" "$pattern" "$log"
    rc=$?
    if [[ $cpu_scope ]]; then
        check_hwlat "$name" "$cpu_scope" "$log" || rc=1
    fi
    if [ "$rc" -eq 0 ]; then
        echo "PASS: $name${cpu_scope:+ ($cpu_scope CPUs)}"
        let pass++
    else
        echo "FAIL: $name${cpu_scope:+ ($cpu_scope CPUs)} rc=$rc"
        let fail++
    fi

    oc delete pod "$name" --ignore-not-found --wait=false &>/dev/null || true
}

dur='/name: DURATION/{n;s/value: .*/value: "10s"/}'
rt='/name: RUNTIME_SECONDS/{n;s/value: .*/value: "10"/}'
delay0='/name: [Dd]elay\|name: DELAY/{n;s/value: .*/value: "0"/}'
pause_n='/securityContext:/i\    - name: PAUSE\n      value: "n"'
all_cpus='/name: ALL_CPUS/{n;s/value: .*/value: "y"/}'
image_opts=()
[[ ${TAG:-} ]] && image_opts+=(-e "s|\(image: quay.io/container-perf-tools/[^:]*\).*|\1:$TAG|")
[[ ${ORG:-} ]] && image_opts+=(-e "s|quay.io/container-perf-tools/|quay.io/$ORG/|")

run_test cyclictest  '^# Thread'  -e "$dur" -e "$delay0"
run_test oslat       'Duration:'  -e "$rt"  -e "$delay0"
run_test hwlatdetect '^test finished$' pod -e "$rt" -e "$delay0"
run_test hwlatdetect '^test finished$' all -e "$rt" -e "$delay0" -e "$all_cpus"
run_test stress-ng   'successful' -e "$dur"
run_test timerlat    'trace data' -e "$dur" -e "$delay0" -e "$pause_n"
run_test osnoise     'trace data' -e "$dur" -e "$delay0" -e "$pause_n"
run_test hwnoise     'trace data' -e "$dur" -e "$delay0" -e "$pause_n"

echo "Results: $pass passed, $fail failed"
exit "$fail"
