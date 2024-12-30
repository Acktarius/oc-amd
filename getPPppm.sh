#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023-2024, Acktarius
####################################
#function to get array of neutral value for pp_power_profile_mode

#trip
#trip
trip() {
kill -INT $$
}

getPPppm() {
firstLine=$(cat ${1}/pp_power_profile_mode | head -n 3 | tail -n 1 | tr -s " ")
firstLine=${firstLine/"( GFXCLK)"/}
echo $firstLine
}

getPPppm $1
