package main

import (
	"fmt"
	"strconv"
)

func intToString(a []int, delim string) string {
	b := ""
	for _, v := range a {
		if len(b) > 0 {
			b += delim
		}
		b += strconv.Itoa(v)
	}
	return b
}

func portMask(ports int) string {
	var a uint8
	for i := 0; i < ports; i++ {
		a = a | (1 << i)
	}
	return fmt.Sprintf("%#x", a)
}
