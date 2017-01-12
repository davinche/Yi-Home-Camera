#!/bin/sh
dir="/home/hd1/record/"
days=+15

find ${dir} -mtime $days -exec rm -Rf {} \+
