package main

import (
	"io/ioutil"
	"regexp"

	"k8s.io/kubernetes/pkg/kubelet/cm/cpuset"
)

func getProcCpuset() cpuset.CPUSet {
	content, err := ioutil.ReadFile("/proc/self/status")
	if err != nil {
		panic(err)
	}
	r := regexp.MustCompile(`Cpus_allowed_list:\s*([0-9,-]*)\r?\n`)
	cpus := r.FindStringSubmatch(string(content))[1]
	return cpuset.MustParse(cpus)
}
