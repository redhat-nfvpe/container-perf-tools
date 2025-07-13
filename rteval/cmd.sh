#!/bin/bash

# env vars:
#   LOAD_CPUS: Specifies CPUs on which to run a CPU-intensive task. If not set, defaults to an empty string.
#   MEASUREMENT_CPU: Designates the CPU to monitor during the test. If not set, defaults to an empty string.
#   THRESHOLD: Determines a latency threshold. Default is 150.
#   TRACE_CMD: If set to 'y', trace-cmd will be utilized. Options are 'y' or 'n'. Default is 'n'.
#   SET_BREAK: If set to 'y', a break point is created. Options are 'y' or 'n'. Default is 'n'.
#   GEN_REPORT: If active ('y'), a report will be generated post-test. Choices include 'y' or 'n'. Default is 'n'.
#   DURATION: Specifies the duration of the test. Default value is 720 minutes (12 hours).
#   DELAY: Dictates the initial delay in seconds before the test starts. Default is 0 seconds.
#   ONLYLOAD: If set to 'y', only the loading test will be executed. Options are 'y' or 'n'. Default is 'n'.
#   QUIET: If enabled ('y'), the tool operates in quiet mode. Options are 'y' or 'n'. Default is 'n'.
#   VERBOSE: If set to 'y', the tool operates in verbose mode. Options are 'y' or 'n'. Default is 'n'. Overrides QUIET.
#   PAUSE: If set to 'y', a pause is induced after the test completes. Options are 'y' or 'n'. Default is 'n'.
#   MANUAL: If enabled ('y'), allows for manual initiation of the test. Options are 'y' or 'n'. Default is 'n'.
#   EXTRA_ARGS: Permits custom options to be added. Default is blank. Provide as a space-separated list.
#   EVENTS: Lists multiple trace events. Default includes a combination of scheduler, IRQ, and softIRQ events. Events should be provided in a comma-separated manner.
#   LIST_TRACE_EVENTS: If set to 'y', lists available trace events and exits. Options are 'y' or 'n'. Default is 'n'.

source common-libs/functions.sh

# Functions for logging
function create_file() {
	tool="rteval"
    log_dir="/var/log/app/$tool"
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
    timestamp=$(date +%Y%m%d%H%M%S)
    file_path="$log_dir/$timestamp.log"
    touch "$file_path"
    echo "$file_path"
}

function log_echo() {
    local message=$1
    echo "$message" >> "$log_file"
    echo "$message"
}

if [[ "${help:-}" == "y" ]]; then
    echo "Usage:"
    echo ""
    echo "Options:"
    echo "  help=y                  Show this help message"
    echo "  LOAD_CPUS=value         Specifies CPUs to run a CPU-intensive task. Default is blank."
    echo "  MEASUREMENT_CPU=value   Designates CPU to monitor during test. Default is blank."
    echo "  THRESHOLD=value         Determines a latency threshold. Default is 150."
    echo "  TRACE_CMD=value         Use trace-cmd. Options are 'y' or 'n'. Default is 'n'."
    echo "  SET_BREAK=value         Creates a break point. Options are 'y' or 'n'. Default is 'n'."
    echo "  GEN_REPORT=value        Generate report post-test. Choices are 'y' or 'n'. Default is 'n'."
    echo "  DURATION=value          Set test duration. Default is 720m (12 hours)."
    echo "  DELAY=value             Delay in seconds before test starts. Default is 0."
    echo "  ONLYLOAD=value          Only execute the loading test. Options are 'y' or 'n'. Default is 'n'."
    echo "  QUIET=value             Operate in quiet mode. Options are 'y' or 'n'. Default is 'n'."
    echo "  VERBOSE=value           Operate in verbose mode. Options are 'y' or 'n'. Default is 'n'. Overrides QUIET."
    echo "  PAUSE=value             Pause after test completion. Options are 'y' or 'n'. Default is 'n'."
    echo "  MANUAL=value            Allow manual test initiation. Options are 'y' or 'n'. Default is 'n'."
    echo "  EXTRA_ARGS=value        Specify custom options. Default is blank. Provide as space-separated list."
    echo "  EVENTS=value            Specify multiple trace events. Default includes scheduler, IRQ, and softIRQ events. Provide as comma-separated list."
    echo "  LIST_TRACE_EVENTS=y     List available trace events and exit."
    exit 0
fi

if [[ "${LIST_TRACE_EVENTS:-}" == "y" ]]; then
    trace-cmd list -e
    exit 0
fi


# Default parameters for rteval
LOAD_CPUS=${LOAD_CPUS:-""}
MEASUREMENT_CPU=${MEASUREMENT_CPU:-""}
THRESHOLD=${THRESHOLD:-150}
TRACE_CMD=${TRACE_CMD:-n}
SET_BREAK=${SET_BREAK:-n}
GEN_REPORT=${GEN_REPORT:-n}
DURATION=${DURATION:-720m}
DELAY=${DELAY:-0}
ONLYLOAD=${ONLYLOAD:-n}
QUIET=${QUIET:-n}
PAUSE=${PAUSE:-n}
MANUAL=${MANUAL:-n}
EXTRA_ARGS=${EXTRA_ARGS:-""}
EVENTS=${EVENTS:-"sched:sched_switch,sched:sched_wakeup,sched:sched_wakeup_new,sched:sched_stat_wait,sched:sched_stat_iowait,sched:sched_stat_blocked,irq"}


log_file=$(create_file rteval)
log_echo "Storing log files at $log_file"
log_echo "INFO: Mount a volume at /var/log/app to persist logs!!!"

# convert the custom_options string into an array
original_ifs="$IFS" #for resetting IFS
IFS=' ' read -r -a custom_options_arr <<< "$EXTRA_ARGS"
IFS=$original_ifs
IFS=',' read -r -a events_array <<< "$EVENTS"
IFS=$original_ifs

log_echo "############# dumping env ###########"
dump=$(env)
log_echo "$dump"
log_echo "#####################################"

log_echo " "
log_echo "########## container info ###########"
log_echo "/proc/cmdline:"
cmdline=$(cat /proc/cmdline)
log_echo "$cmdline"
log_echo "#####################################"

log_echo "**** uid: $UID ****"

# Check if the command is installed
for cmd in rteval trace-cmd; do
    command -v $cmd >/dev/null 2>&1 || { log_echo "$cmd required but not installed. Aborting"; exit 1; }
done

uname=$(uname -nr) # get the kernel version major number
log_echo "$uname"
version=$(rpm -q rteval)
log_echo "$version"
trace_version=$(rpm -q trace-cmd)
log_echo "$trace_version"

EVENTS="$(echo -e "${EVENTS}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
if [[ $EVENTS =~ [[:space:]] ]]; then
    log_echo "Error: The EVENTS variable contains spaces between words. It should be a comma-separated list without spaces."
    exit 1
fi

# Validate each event
for e in "${events_arr[@]}"; do
    if ! echo "$e" | grep -Pq "^[a-zA-Z0-9_]+(:[a-zA-Z0-9_]+)?$"; then
        log_echo "Invalid event format: $e. It must be one word or two sets of words with a colon in between. Each word can include underscore '_' but no spaces."
        exit 1
    fi
done

# if tracing is enabled, disable some things that may get in the way
if [[ "$TRACE_CMD" == "y" || "$SET_BREAK" == "y" ]]; then
    # If setting a break point for another tool to use, disable reprot generation so it does not intefer.
    if [[ "$GEN_REPORT" == "y" ]]; then
        log_echo "Warning: sosreport generation is enabled with tracing options. This has the potential to inflate the trace data with additional noise."
    fi
    if [[ "$ONLYLOAD" == "y" ]]; then
        log_echo "Warning: Disabling onlyload because tracing is enabled. Onlyload is only used when another tool is doing the measurements and tracing."
        ONLYLOAD="n"
    fi
    if [[ "$SET_BREAK" == "y" && "$TRACE_CMD" == "y" ]]; then
        log_echo "Warning: Disabling SET_BREAK because tracing via trace-cmd is enabled. Please set TRACE_CMD == 'n' to enable SET_BREAK for using with another tool such as rtla or perf."
        SET_BREAK="n"
    fi
fi

# Build the rteval command
if [[ "$TRACE_CMD" == "y" ]]; then
    command_args=("trace-cmd record")
    for e in "${events_array[@]}"; do
        command_args=("${command_args[@]}" "-e" "$e")
    done
    command_args=("${command_args[@]}" "rteval")

else
    command_args=("rteval")
fi

command_args=("${command_args[@]}" "--duration ${DURATION}")

if [[ "${VERBOSE}" == "y" ]]; then
    if [[ "${QUIET}" == "y" ]]; then
        log_echo "Warning: VERBOSE mode and QUIET mod are both enabled. VERBOSE will take precedence."
    fi
    command_args=("${command_args[@]}" "--verbose")
elif [[ "${QUIET}" == "y" ]]; then
    command_args=("${command_args[@]}" "--quiet")
fi

if [[ ! -z "${LOAD_CPUS}" ]]; then
    if [[ -z "${MEASUREMENT_CPUS}" && $ONLYLOAD == "n" ]]; then
        log_echo "Warning: LOAD_CPUS is set but MEASUREMENT_CPUS is not set. Make sure this is intentional."
    fi
    command_args=("${command_args[@]}" "--loads-cpulist=${LOAD_CPUS}")
fi

if [[ "${ONLYLOAD}" == "y" ]]; then
    command_args=("${command_args[@]}" "--onlyload")
else
    if [[ ! -z "${MEASUREMENT_CPUS}" ]]; then
        if [[ -z "${LOAD_CPUS}" ]]; then
            log_echo "Warning: MEASUREMENT_CPUS is set but LOAD_CPUS is not set. Make sure this is intentional."
        fi
        command_args=("${command_args[@]}" "--measurement-cpulist=${MEASUREMENT_CPUS}")
    fi

    if [[ "$SET_BREAK" == "y" || "$TRACE_CMD" == "y" ]]; then
        command_args=("${command_args[@]}" "--cyclictest-breaktrace=${THRESHOLD}")
    else 
        command_args=("${command_args[@]}" "--cyclictest-threshold=${THRESHOLD}")
    fi

    if [[ "${GEN_REPORT}" == "y" ]]; then
        command_args=("${command_args[@]}" "--sysreport")
    fi
fi

if [[ -n "$EXTRA_ARGS" ]]; then
    for opt in "${custom_options_arr[@]}"; do
        command_args=("${command_args[@]}" "$opt")
    done
fi

log_echo "=================================================="
log_echo "RUNNING COMMAND:"
formatted_command=$(printf "%s " "${command_args[@]}")
log_echo "$formatted_command"
log_echo "=================================================="

if [[ "${MANUAL}" == "y" ]]; then
    log_echo "=================== MANUAL MODE ==================="
    log_echo "Entering into MANUAL intervention mode."
    log_echo "Access the container with one of the following based on your environment:"
    log_echo "- Podman: podman exec -it ${HOSTNAME} /bin/bash"
    log_echo "- OC:     oc exec -it rteval -- /bin/bash"
    log_echo "=================================================="
    sleep infinity
fi

if [[ "${DELAY}" != "0" ]]; then
    log_echo "Pausing for ${DELAY} seconds before test..."
    sleep ${DELAY}
fi

output=$(eval "$formatted_command")
log_echo "$output"

log_name="${log_file::-4}" # Remove .log from the name
log_echo "=================================================="
if [ -f "/root/trace.dat" ]; then
    cp "/root/trace.dat" "${log_name}_rteval_trace.dat"
    log_echo "TRACE DATA:"
    log_echo "Trace data copied to: ${log_name}_rteval_trace.dat"
    log_echo "Either mount storage or set PAUSE=y to retrieve it."
fi

if [[ "$GEN_REPORT" == "y" ]]; then
    log_echo "SOSREPORT was generated. Moving it to: ${log_name}_rteval_sosreport.tar.xz"
    cp /var/tmp/sosreport*rteval*tar.xz "${log_name}_rteval_sosreport.tar.xz" 
fi

if [[ "$PAUSE" == "y" ]]; then
    log_echo "================== RETRIEVAL INFO ================="
    log_echo "DONE: If a trace was collected you can retrieve it with:"
    log_echo "- OC:     oc cp rteval:/root/trace.dat trace.dat"
    log_echo "- Podman: podman cp ${HOSTNAME}:/root/${trace_name}_trace.txt ${trace_name}_trace.txt"
    log_echo "If a sosreport was generated you can retrieve it with:"
    log_echo "- OC:     oc cp rteval:${log_name}_rteval_sosreport.tar.xz sosreport-rteval.tar.xz"
    log_echo "- Podman: podman cp ${HOSTNAME}:${log_name}_rteval_sosreport.tar.xz sosreport-rteval.tar.xz"
    log_echo "Pausing after run."
    log_echo "Access the container with one of the following based on your environment:"
    log_echo "- Podman: podman exec -it ${HOSTNAME} /bin/bash"
    log_echo "- OC:     oc exec -it rteval -- /bin/bash"
    log_echo "=================================================="
    sleep infinity
fi
