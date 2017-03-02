#!/bin/sh
dir="/home/hd1/record"
days=+5
mins="+$(($days * 1440))"
find ${dir} -mmin ${mins} -type d | xargs rm -rf
