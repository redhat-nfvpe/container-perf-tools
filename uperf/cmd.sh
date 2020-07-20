#!/bin/bash

# env vars:
#	mode (default manual)
# additional env for master:
#       uperfSlave (slave address)
#       size (write size to slave, default 8192)
#       readSize (read size from slave, default 8192)
#       duration (default 66s)

source common-libs/functions.sh

function sigfunc() {
	exit 0
}

mode=${mode:-manual}
echo "############# dumping env ###########"
env
echo "#####################################"

for cmd in uperf; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed.  Aborting"; exit 1; }
done

trap sigfunc TERM INT SIGUSR1

if [[ "${mode}" == "manual" ]]; then
	sleep infinity	
elif [[ "${mode}" == "slave" ]]; then
	uperf -s
elif [[ "${mode}" == "master" ]]; then
	if [[ "${uperfSlave:-undefined}" == "undefined" ]]; then
		echo "env var: uperfSlave needs to be defined for uperf master"
	else
		export uperfSlave=${uperfSlave}
		export size=${size:-1024}
		export duration=${duration:-60s}
		export profile=${profile:-stream}
		export threads=${threads:-1}
		envsubst <uperf/stream.xml.tmpl >uperf/stream.xml
		envsubst <uperf/request-response.xml.tmpl > uperf/request-response.xml
		if [[ "${profile}" == "rr" ]]; then
			uperf  -m uperf/request-response.xml
		elif [[ "${profile}" == "stream" ]]; then
			uperf  -m uperf/stream.xml
		else
			echo "invalid profile: ${profile}"
		fi

	fi
	sleep infinity	
fi
