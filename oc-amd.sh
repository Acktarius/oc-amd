#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023-2024, Acktarius
####################################
#test card is a RX6400
#glxinfo doesn't work when called from a service
#testgpu=$(glxinfo | grep -c "RX 6400")
# Variables and functions


#declaration variables and functions
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#trip
trip() {
kill -INT $$
}

# get path to card
for ((card_num=0; card_num<=2; card_num++)); do
    path2card="/sys/class/drm/card${card_num}/device"
    if [ -d "${path2card}" ]; then
        device=$(cat ${path2card}/device)
        case "${device}" in
            "0x743f"|"0x73ff"|"0x73ef"|"0x747e")
                break
                ;;
            *)
                echo "Skipping card${card_num}: unsupported device ID ${device}"
                continue
                ;;
        esac  
    fi
    if [ $card_num -eq 2 ]; then
        echo "Error: No supported GPU device found (checked card0, card1, card2)"
        exit 1
    fi
done


# expected device
# RX6400 or RX6500 or RX6500XT = 0x743f
# RX6600 or RX6600XT = 0x73ff
# RX6650XT = 0x73ef
# RX6800XT = 0x73bf
# RX7800XT = 0x747e

revision=$(cat ${path2card}/revision)

if [[ "${device}" != "0x743f" ]] && \
[[ "${device}" != "0x73ff" ]] && \
[[ "${device}" != "0x73ef" ]] && \
[[ "${device}" != "0x73bf" ]]&& \
[[ "${device}" != "0x747e" ]] ; then
echo "$device"
echo "your device is not supported"
sleep 2
exit
else


#fetch overclocks
card=$(source ${SCRIPT_DIR}/check_device.sh $device $revision)
echo "$card"
link2oc="${SCRIPT_DIR}/oc_start_${card}.txt"

#check oc file exist	
if [[ ! -f "$link2oc" ]]; then
    echo "Error: Overclock configuration file not found: $link2oc"
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
minpl=$(cat ${path2card}/hwmon/hwmon*/power1_cap_min)
maxpl=$(cat ${path2card}/hwmon/hwmon*/power1_cap_max)
# echo $minpl > ${path2card}/hwmon/hwmon*/power1_cap #----------------since we cannot lower than cap_min
if (( $pl >= $minpl )) && (( $pl <= $maxpl )); then
	echo $pl > ${path2card}/hwmon/hwmon*/power1_cap
else
	echo "Warning: Power limit $pl is outside allowed range ($minpl - $maxpl)"
fi
#set power profile
#get index value of profile mode
profile=$(cat $link2oc | grep 'profile' | cut -d " " -f 3)
if [[ "$profile" != "CUSTOM" ]]; then 
mode=$(cat ${path2card}/pp_power_profile_mode | grep $profile | tr -s " " | cut -d " " -f 2)
	if  [[ "$mode" =~ ^[0-9]+$ ]]; then
	echo $mode > ${path2card}/pp_power_profile_mode
	fi
else
declare -a neutral
neutral=($(source ${SCRIPT_DIR}/getPPppm.sh ${path2card}))
neutral[4]=$(cat $link2oc | grep 'baseCclk' | cut -d " " -f 3)
neutral[6]=$(cat $link2oc | grep 'boostCclk' | cut -d " " -f 3)
echo "6 ${neutral[@]}" > ${path2card}/pp_power_profile_mode
fi

#set value for mem
mclk=$(cat $link2oc | grep 'mclk' | cut -d " " -f 3)
echo $mclk > ${path2card}/pp_dpm_mclk

#VDD_OFFSET
if [ -f "${path2card}/pp_od_clk_voltage" ]; then
    vo=$(cat $link2oc | grep 'vo' | cut -d " " -f 3)
    echo "vo ${vo}" > ${path2card}/pp_od_clk_voltage
    #COMMIT PP_OD_CLK_VOLTAGE
    echo "c" > ${path2card}/pp_od_clk_voltage
else
    echo "Warning: pp_od_clk_voltage not available for this GPU, skipping voltage offset"
fi

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
