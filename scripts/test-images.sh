#!/bin/bash

# Smoke test for container-perf-tools images
# Runs each tool as a pod, monitors logs, validates output

set -uo pipefail

d=$(dirname "$(readlink --canonicalize "$0")")/..
timeout=${TIMEOUT:-120}
pass=0
fail=0

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
    oc wait --for=condition=Ready --timeout=3m pod $name >/dev/null

    timeout "$timeout" oc logs --follow "pod/$name" >> "$log" &
    local pid=$!
    tail --follow --pid=$pid --lines=+1 "$log" |
        while IFS= read -r line; do
            [[ $line =~ Aborting|Traceback|^Error:|ValueError|Failed.to.enable ]] && kill $pid 2>/dev/null && break
            [[ $line =~ $pattern ]] && kill $pid 2>/dev/null && break
        done
    wait $pid 2>/dev/null

    grep --quiet --ignore-case "$pattern" "$log"
    rc=$?
    if [[ $cpu_scope ]]; then
        local reported_cpus=$(awk '$1 == "CPU" && $2 == "list:" { print $3 }' "$log")
        if [[ $cpu_scope == pod ]]; then
            local expected_cpus=$(oc exec "pod/$name" -- cat /proc/self/status | awk '$1 == "Cpus_allowed_list:" { print $2 }')
            if [[ ! $expected_cpus || $reported_cpus != "$expected_cpus" ]]; then
                echo "Expected pod CPU list: $expected_cpus"
                rc=1
            fi
        elif [[ $reported_cpus != None ]]; then
            echo "Expected CPU list: None for ALL_CPUS=y"
            rc=1
        fi
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
run_test hwlatdetect 'finished' pod -e "$rt" -e "$delay0"
run_test hwlatdetect 'finished' all -e "$rt" -e "$delay0" -e "$all_cpus"
run_test stress-ng   'successful' -e "$dur"
run_test timerlat    'trace data' -e "$dur" -e "$delay0" -e "$pause_n"
run_test osnoise     'trace data' -e "$dur" -e "$delay0" -e "$pause_n"
run_test hwnoise     'trace data' -e "$dur" -e "$delay0" -e "$pause_n"

echo "Results: $pass passed, $fail failed"
exit "$fail"
