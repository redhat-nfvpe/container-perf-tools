#!/usr/bin/bash

# Starting in background with logger:
#
# nohup taskset -c 40 ./sched-trace.sh | taskset -c 40 logger --tag sched-trace &

tracing=/sys/kernel/debug/tracing

# reset
echo 0 > $tracing/tracing_on
echo > $tracing/trace
for e in $tracing/events/**/enable; do
	echo 0 > $e
done

enable=(
	timer # traces funcs hrtimer_* tick_*
	workqueue 
	sched/sched_switch
	sched/sched_migrate_task
	sched/sched_wakeup
	sched/sched_waking
	irq
	irq_vectors # traces funcs local_*
)

for e in $enable; do
	echo 1 > $tracing/events/$e/enable
done

echo 1 > $tracing/options/stacktrace

grep -r $tracing/ --include enable -e 1

echo 1 > $tracing/tracing_on

sigfunc()
{
	echo exiting
	echo 0 > $tracing/tracing_on
	exit
}

trap sigfunc TERM INT SIGUSR1

while true; do
	# compact timestamp
	timestamp=$(date "+%y%m%d-%H%M%S")
	prev=$SECONDS
	sleep 1
	delay=$((SECONDS - prev - 1))
	if [[ $delay -ge 1 ]]; then
		# pause the tracing
		echo 0 > /sys/kernel/debug/tracing/tracing_on
		fn=sched-trace-$timestamp-$delay.log
		cat $tracing/trace > $fn
		ls --human-readable --size $fn

		# restart
		echo > $tracing/trace
		echo 1 > $tracing/tracing_on
	fi
done

# References:
# https://docs.google.com/presentation/d/1A1OHPswG3tAVxXQkzao32ckgTY0PrXrLlNIn-pwzVIs/edit#slide=id.g111c8b2a622_2_0
