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
path2card() {
echo $(readlink -f "/sys/class/drm/card${1}/device")
}

# loop through cards
for ((i = 1 ; i < 10 ; i++)); do
    if [[ ! -d $(path2card $i) ]]; then
    break
    fi
        pathToCard=$(path2card $i)
        device=$(echo $(cat ${pathToCard}/device))
        revision=$(echo $(cat ${pathToCard}/revision)) || $(echo "null")
        echo "gpu: ${device}, revision: ${revision}"
        card=$(source check_device.sh $device $revision)
        echo $card
        ocFile="oc_start_${card}.txt"
        #check oc file exist	
        if [[ ! -f "$ocFile" ]]; then
        echo "no oc file for ${card}"
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
            if  [[ "$mode" =~ ^[0-9]+$ ]]; then
                echo $mode > ${pathToCard}/pp_power_profile_mode
            fi
            #set value for mem
            mclk=$(cat $ocFile | grep 'mclk' | cut -d " " -f 3)
            echo $mclk > ${pathToCard}/pp_dpm_mclk
            #set fan manual
            fmode=$(cat $ocFile | grep 'fmode' | cut -d " " -f 3)
            echo $fmode > ${pathToCard}/hwmon/hwmon*/pwm1_enable
            #set fan speed
            fspeed=$(cat $ocFile | grep 'fspeed' | cut -d " " -f 3)
            echo $fspeed > ${pathToCard}/hwmon/hwmon*/pwm1    
                ;;
            esac
        fi
((i++))
done

