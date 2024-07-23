#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023-2024, Acktarius
####################################
#test card is a RX6400
#glxinfo doesn't work when called from a service
#testgpu=$(glxinfo | grep -c "RX 6400")
# Variables and functions

#trip
trip() {
kill -INT $$
}

# get path to card
path2card=$(readlink -f /sys/class/drm/card0/device)

device=$(cat ${path2card}/device)
# expected device
# RX6400 or RX6500 or RX6500XT = 0x743f
# RX6600 or RX6600XT = 0x73ff
# RX6650XT = 0x73ef

revision=$(cat ${path2card}/revision)

if [[ "${device}" != "0x743f" ]] && [[ "${device}" != "0x73ff" ]] && [[ "${device}" != "0x73ef" ]] ; then
echo "$device"
echo "your device is not supported"
sleep 2
exit
else

#fetch overclocks

case "$device" in
# RX6400 or RX6500 or RX6500XT
	"0x743f")
	case "$revision" in
		"0xc7")
		card="RX6400"
		;;
		"0xc3")
		card="RX6500"
		;;
		"0xc1")
		card="RX6500XT"
		;;
		*)
		echo "unexpected card revision"
		trip
		;;
	esac
	;;
# RX6600 series
	"0x73ff")
	case "$revision" in
		"0xc7")
		card="RX6600"
		;;
		"0xc1")
		card="RX6600XT"
		;;
		*)
		echo "unexpected card revision"
                trip
		;;
	esac
	;;
# RX 6650XT
	"0x73ef")
	case "$revision" in
		"0xc1")
		card="RX6650XT"
		;;
		*)
		echo "unexpected card revision"
                trip
		;;
	esac
	;;
	*)
echo "unexpected error"
sleep 2
exit
	;;
esac

link2oc="/opt/conceal-toolbox/oc-amd/oc_start_${card}.txt"

#check oc file exist	
if [[ ! -f "$link2oc" ]]; then
echo "no oc file"
trip
fi


# oc or reset ?
case "$1" in
	reset|R)

#set power to default ------------------------------------------------------------------- < reset
pldefault=$(cat ${path2card}/hwmon/hwmon*/power1_cap_default)
echo $pldefault > ${path2card}/hwmon/hwmon*/power1_cap

#set fan auto
echo 2 > ${path2card}/hwmon/hwmon*/pwm1_enable

#Set performance to auto
echo "auto" > ${path2card}/power_dpm_force_performance_level

echo "Done, welcome back to normal"

	;;
	*)

#set  Performance to manual ------------------------------------------------------------- < over-clocking
echo "manual" > ${path2card}/power_dpm_force_performance_level

#set power
pl="$(cat $link2oc | grep 'pl' | cut -d " " -f 3)000000"
maxpl=$(cat ${path2card}/hwmon/hwmon*/power1_cap_max)
if (( $pl <= $maxpl )); then
	echo $pl > ${path2card}/hwmon/hwmon*/power1_cap
fi
#set power profile
#get index value of profile mode
profile=$(cat $link2oc | grep 'profile' | cut -d " " -f 3)
mode=$(cat ${path2card}/pp_power_profile_mode | grep $profile | tr -s " " | cut -d " " -f 2)
if  [[ "$mode" =~ ^[0-9]+$ ]]; then
	echo $mode > ${path2card}/pp_power_profile_mode
fi
#set value for mem
mclk=$(cat $link2oc | grep 'mclk' | cut -d " " -f 3)
echo $mclk > ${path2card}/pp_dpm_mclk
#set fan manual
fmode=$(cat $link2oc | grep 'fmode' | cut -d " " -f 3)
echo $fmode > ${path2card}/hwmon/hwmon*/pwm1_enable
#set fan speed
fspeed=$(cat $link2oc | grep 'fspeed' | cut -d " " -f 3)
echo $fspeed > ${path2card}/hwmon/hwmon*/pwm1

echo "Done, happy hashing !" 
	;;
esac

fi
