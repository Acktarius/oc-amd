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
path2card() {
echo $(readlink -f "/sys/class/drm/card${1}/device")
}

# loop through cards
for ((i = 0 ; i < 10 ; i++)); do
    if [[ ! -d $(path2card $i) ]]; then
    break
    fi
        pathToCard=$(path2card $i)
        device=$(echo $(cat ${pathToCard}/device))
        revision=$(echo $(cat ${pathToCard}/revision)) || $(echo "null")
        card=$(source ${SCRIPT_DIR}/check_device.sh $device $revision)
        ocFile="oc_start_${card}.txt"
        #check oc file exist
        if [[ ! -f "$ocFile" ]]; then
        echo "no oc file for card${i} : ${card}"
        else
            # oc or reset ?
            case "$1" in
                reset|R)

            #set power to default ------------------------------------------------------------------- < reset
            pldefault=$(cat ${pathToCard}/hwmon/hwmon*/power1_cap_default)
            echo $pldefault > ${pathToCard}/hwmon/hwmon*/power1_cap
            #set fan auto
            echo 2 > ${pathToCard}/hwmon/hwmon*/pwm1_enable
            #Set performance to auto
            echo "auto" > ${pathToCard}/power_dpm_force_performance_level
            echo -e "card${i} : ${card} overclocks reset" 
		 ;;
                *)
            #set  Performance to manual ------------------------------------------------------------- < over-clocking
            echo "manual" > ${pathToCard}/power_dpm_force_performance_level

            #set power
            pl="$(cat $ocFile | grep 'pl' | cut -d " " -f 3)000000"
            maxpl=$(cat ${pathToCard}/hwmon/hwmon*/power1_cap_max)
            if (( $pl <= $maxpl )); then
                echo $pl > ${pathToCard}/hwmon/hwmon*/power1_cap
            fi
            #set power profile
            #get index value of profile mode
            profile=$(cat $ocFile | grep 'profile' | cut -d " " -f 3)
            mode=$(cat ${pathToCard}/pp_power_profile_mode | grep $profile | tr -s " " | cut -d " " -f 2)
            if [[ "$profile" != "CUSTOM" ]]; then 
	     if  [[ "$mode" =~ ^[0-9]+$ ]]; then
                echo $mode > ${pathToCard}/pp_power_profile_mode
            	fi
	     # CUSTOM selected, injection of Base clock and boost
	    else
	declare -a neutral
	neutral=($(source ${SCRIPT_DIR}/getPPppm.sh ${path2card}))
	neutral[4]=$(cat $link2oc | grep 'baseCclk' | cut -d " " -f 3)
	neutral[6]=$(cat $link2oc | grep 'boostCclk' | cut -d " " -f 3)
	echo "6 ${neutral[@]}" > ${path2card}/pp_power_profile_mode
 	unset neutral
	    fi
            #set value for mem
            mclk=$(cat $ocFile | grep 'mclk' | cut -d " " -f 3)
            echo $mclk > ${pathToCard}/pp_dpm_mclk
            #VDD_OFFSET
            vo=$(cat $ocFile | grep 'vo' | cut -d " " -f 3)
            echo "vo ${vo}" >  ${pathToCard}/pp_od_clk_voltage
            #COMMIT PP_OD_CLK_VOLTAGE
            echo "c" >  ${pathToCard}/pp_od_clk_voltage
            #set fan manual
            fmode=$(cat $ocFile | grep 'fmode' | cut -d " " -f 3)
            echo $fmode > ${pathToCard}/hwmon/hwmon*/pwm1_enable
            #set fan speed
            fspeed=$(cat $ocFile | grep 'fspeed' | cut -d " " -f 3)
            echo $fspeed > ${pathToCard}/hwmon/hwmon*/pwm1    
	    echo  -e "oc applied to card${i} : ${card} \n"
     		
                ;;
            esac
        fi
done
