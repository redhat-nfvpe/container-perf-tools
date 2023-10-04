#!/bin/bash

# env vars:
#   DURATION (Set the duration. Default: 24h.)
#   COMMAND ( choices "timerlat", "hwnoise", or "osnoise". If none are given, we error.)
#   PAUSE (default: y, pauses after run. choices y/n)
#   DELAY (default 0, specify how many seconds to delay before test start)
#   AA_THRESHOLD (default 20, sets automatic trace mode stopping the session if latency in us is hit. A value of 0 disables this feature)
#   MAX_LATENCY (default 0, if set, stops trace if the thread latency is higher than the argument in us. This overrides the -a flag and its value if it is not 0)
#   EVENTS (Allows specifying multiple trace events. Default is blank. This should be provided as a comma separated list.)
#   EVENTS_TRIGGER (Optional. Specifies the condition for the event trigger. This should be provided if EVENTS is not blank.)
#   CHECK_US (Allows RTLA to also check for userspace induced latency. Options are 'y' or 'n'. Default is 'n'.)
#   CGROUPS (If set to 'y', it places the rtla kthreads in the same cgroup as the userspace threads. Default is 'n'. Choices are 'y' or 'n'.
#   EXTRA_ARGS (Allows specifying custom options. Default is blank. Provide as a space separated list of options.)

source common-libs/functions.sh

# Functions for logging
function create_file() {
	tool=$1
    log_dir="/var/log/app/$tool"

    # Check if directories exist, if not, create them
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
    echo "  help=y               Show this help message"
    echo "  DURATION=value       Set the duration. Default: 24h."
    echo "  COMMAND=value        Required. Set command mode. Choices are 'timerlat', 'hwnoise', or 'osnoise'."
    echo "  PAUSE=value          Pause after run. Default is 'y'. Choices are 'y' or 'n'."
    echo "  DELAY=value          Specify how many seconds to DELAY before test start. Default is 0."
    echo "  AA_THRESHOLD=value   Sets automatic trace mode stopping the session if latency in us is hit. Default is 20."
    echo "  MAX_LATENCY=value    If set, stops trace if the thread latency is higher than the value in us. Default is 0."
    echo "  EVENTS=value         Allows specifying multiple trace events. Default is blank. This should be provided as a comma separated list."
    echo "  EVENT_TRIGGER=value  (Optional) Specifies the condition for the event trigger. This should be provided if EVENTS is not blank."
    echo "  CHECK_US=value       Allows RTLA to also check for userspace induced latency. Options are 'y' or 'n'. Default is 'n'."
    echo "  CGROUPS=value        If set to 'y', it places the rtla kthreads in the same cgroup as the userspace threads. Default is 'n'. Choices are 'y' or 'n'."
    echo "  EXTRA_ARGS=value     Allows specifying custom options. Default is blank. Provide as a space separated list of options."
    exit 0
fi

# Initialize default variables
COMMAND=${COMMAND:-""}
PAUSE=${PAUSE:-"y"}
DELAY=${DELAY:-0}
DURATION=${DURATION:-"24h"}
MANUAL=${MANUAL:-n}
AA_THRESHOLD=${AA_THRESHOLD:-20}
MAX_LATENCY=${MAX_LATENCY:-0}
EVENTS=${EVENTS:-""}
EVENTS_TRIGGER=${EVENTS_TRIGGER:-""}
CHECK_US=${CHECK_US:-n}
EXTRA_ARGS=${EXTRA_ARGS:-""}
CGROUPS=${CGROUPS:-n}

log_file=$(create_file $COMMAND)
echo "Storing log files at $log_file"
echo "INFO: Mount a volume at /var/log/app to persist logs!!!"

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
for cmd in rtla; do
    command -v $cmd >/dev/null 2>&1 || { log_echo "$cmd required but not installed. Aborting"; exit 1; }
done

uname=$(uname -nr) # get the kernel version major number
log_echo "$uname"
version=$(rpm -q rtla)
log_echo "$version"

# Check the mode
case "$COMMAND" in
    "timerlat"|"hwnoise"|"osnoise")
        log_echo "Operating in $COMMAND mode."
        ;;
    *)
        log_echo "Error: Invalid mode. Please set COMMAND to 'timerlat', 'hwnoise', or 'osnoise'."
        exit 1
        ;;
esac

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

cpulist=$(get_allowed_cpuset)
log_echo "allowed cpu list: $cpulist"

# change list seperators from comma to new line and sort it
cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort -n | uniq`

declare -a cpus
cpus=(${cpulist})

cyccore=${cpus[1]}
cindex=2
ccount=1
while (( $cindex < ${#cpus[@]} )); do
    cyccore="${cyccore},${cpus[$cindex]}"
    cindex=$(($cindex + 1))
    ccount=$(($ccount + 1))
done

sibling=`cat /sys/devices/system/cpu/cpu${cpus[0]}/topology/thread_siblings_list | awk -F '[-,]' '{print $2}'`
if [[ "${sibling}" =~ ^[0-9]+$ ]]; then
    log_echo "removing cpu${sibling} from the cpu list because it is a sibling of cpu${cpus[0]} which will be the cpu-main-thread"
    cyccore=${cyccore//,$sibling/}
fi
log_echo "new cpu list: ${cyccore}"

if [ ${COMMAND} == "timerlat" ] || [ ${COMMAND} == "osnoise" ]; then
    hist="hist"
fi

# Set the generic shared components of the tools
command_args=("rtla" "$COMMAND" "$hist" "-c" "$cyccore" -H ${cpus[0]})

# Set the generic shared options
if [[ -z "${DURATION}" ]]; then
    log_echo "running rtla with out timeout"
else
    command_args=("${command_args[@]}" "-d" "${DURATION}")
fi

if [[ "${CHECK_US}" == "y" && "${COMMAND}" == "timerlat" ]]; then
    command_args=("${command_args[@]}" "-u")
fi

# Add the -C option if CGROUPS is set to 'y'
# Note: If you want to use a specific cgroup slice,
# then you need to pass -C <slice_name> with EXTRA_ARGS
# and also set cgroupsns=host with the container runtime.
if [[ "${CGROUPS}" == "y" ]]; then
        command_args=("${command_args[@]}" "-C")
fi

if [[ -n "$EXTRA_ARGS" ]]; then
    for opt in "${custom_options_arr[@]}"; do
        command_args=("${command_args[@]}" "$opt")
    done
fi

if [[ -n "$EVENTS" ]]; then
    for e in "${events_array[@]}"; do
        command_args=("${command_args[@]}" "-e" "$e")
    done
    # If EVENTS_TRIGGER is provided, add the --trigger option
    if [[ -n "$EVENTS_TRIGGER" ]]; then
        command_args=("${command_args[@]}" "--trigger" "'$EVENTS_TRIGGER'")
    fi

fi

if [[ "${MAX_LATENCY}" -ne 0 ]]; then
    command_args=("${command_args[@]}" "-T" "$MAX_LATENCY")
elif [[ "${AA_THRESHOLD}" -eq 0 && "${MAX_LATENCY}" -eq 0 ]]; then
    log_echo "Not using --auto-analysis feature"
else
    command_args=("${command_args[@]}" "-a" "$AA_THRESHOLD")
fi

if [[ -n "$EVENTS" ]] || [[ -n "$EVENT_TRIGGER" ]]; then
    log_echo "==================== EVENT FILTER CHEATSHEET ==================="
    log_echo "To find valid information about events and triggers, run the container with MANUAL=y or PAUSE=y and follow these instructions:"
    log_echo "1. To find all valid events:"
    log_echo "   find /sys/kernel/debug/tracing/events/ -type f -name \"format\" | sed -e 's,^.*/events/,,' -e 's,/format$,,' | awk -F/ '{print \$1\":\"\$2}'"
    log_echo "2. For the format of a specific event:"
    log_echo "   cat /sys/kernel/debug/tracing/events/<event_category>/<event_name>/format"
    log_echo "3. Example for 'irq_vectors:irq_work_entry':"
    log_echo "   cat /sys/kernel/debug/tracing/events/irq_vectors/irq_work_entry/format"
    log_echo "=================================================="
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
    log_echo "- OC:     oc exec -it ${COMMAND} -- /bin/bash"
    log_echo "=================================================="
    sleep infinity
fi

if [[ "${DELAY}" != "0" ]]; then
    log_echo "Pausing for ${DELAY} seconds before test..."
    sleep ${DELAY}
fi

output=$(eval "$formatted_command")
log_echo "$output"

# Right now hwnoise saves its trace as osnoise
if [[ "$COMMAND" == "hwnoise" ]]; then
    trace_name="osnoise"
else
    trace_name="$COMMAND"
fi

log_name="${log_file::-4}" # Remove .log from the name
log_echo "=================================================="
if [ -f "/root/${trace_name}_trace.txt" ]; then
    cp "/root/${trace_name}_trace.txt" "${log_name}_${COMMAND}_trace.txt"
    log_echo "TRACE DATA"
    log_echo "Trace data copied to: ${log_name}_${COMMAND}_trace.txt"
    log_echo "Either mount storage or set PAUSE=y to retrieve it."
else
    log_echo "WARNING: Trace Data Missing!"
    log_echo "/root/${trace_name}_trace.txt does not exist."
    log_echo "No trace data was generated with the ${COMMAND} option."
fi
log_echo "=================================================="

if [[ "$PAUSE" == "y" ]]; then
    log_echo "================== RETRIEVAL INFO ================="
    log_echo "DONE: If a trace was collected you can retrieve it with:"
    log_echo "- OC:     oc cp ${COMMAND}:/root/${trace_name}_trace.txt ${trace_name}_trace.txt"
    log_echo "- Podman: podman cp ${HOSTNAME}:/root/${trace_name}_trace.txt ${trace_name}_trace.txt"
    log_echo "Pausing after run."
    log_echo "Access the container with one of the following based on your environment:"
    log_echo "- Podman: podman exec -it ${HOSTNAME} /bin/bash"
    log_echo "- OC:     oc exec -it ${COMMAND} -- /bin/bash"
    log_echo "=================================================="
    sleep infinity
fi
