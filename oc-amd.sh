#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023, Acktarius
#################################
#test card is a RX6400
#glxinfo doesn't work when called from a service
#testgpu=$(glxinfo | grep -c "RX 6400")
# get path to card
path2card=$(readlink -f /sys/class/drm/card0/device)

device=$(cat ${path2card}/device)

if [[ "$device" == "0x743f" ]] ; then


# oc or reset ?
case "$1" in
	reset|R)

#set power to default
pldefault=$(cat ${path2card}/hwmon/hwmon*/power1_cap_default)
echo $pldefault > ${path2card}/hwmon/hwmon*/power1_cap

#set fan auto
echo 2 > ${path2card}/hwmon/hwmon*/pwm1_enable

#Set performance to auto
echo "auto" > ${path2card}/power_dpm_force_performance_level

echo "Done, welcome back to normal"
	;;
	*)
#set  Performance to manual
echo "manual" > ${path2card}/power_dpm_force_performance_level
#set power
pl="$(cat /opt/conceal-toolbox/oc-amd/oc_start.txt | grep 'pl' | cut -d " " -f 3)000000"
maxpl=$(cat ${path2card}/hwmon/hwmon*/power1_cap_max)
if (( $pl <= $maxpl )); then
	echo $pl > ${path2card}/hwmon/hwmon*/power1_cap
fi
#set power profile
#get value of power save mode
mode=$(cat ${path2card}/pp_power_profile_mode | grep "POWER_SAVING" | tr -s " " | cut -d " " -f 2)
if  [[ "$mode" =~ ^[0-9]+$ ]]; then
	echo $mode > ${path2card}/pp_power_profile_mode
fi
#set value for mem
mclk=$(cat /opt/conceal-toolbox/oc-amd/oc_start.txt | grep 'mclk' | cut -d " " -f 3)
echo $mclk > ${path2card}/pp_dpm_mclk
#set fan manual
fmode=$(cat /opt/conceal-toolbox/oc-amd/oc_start.txt | grep 'fmode' | cut -d " " -f 3)
echo $fmode > ${path2card}/hwmon/hwmon*/pwm1_enable
#set fan speed
fspeed=$(cat /opt/conceal-toolbox/oc-amd/oc_start.txt | grep 'fspeed' | cut -d " " -f 3)
echo $fspeed > ${path2card}/hwmon/hwmon*/pwm1

echo "Done, happy hashing !" 
	;;
esac

fi
