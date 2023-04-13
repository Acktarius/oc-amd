#!/bin/bash
#regulate GPU temp
# this file is subject to Licence
#Copyright (c) 2023, Acktarius
#################################
# get path to card
path2card=$(readlink -f /sys/class/drm/card0/device)
gput=$(sensors | grep "edge" | cut -d "+" -f 2 | cut -d "." -f 1)
echo "actual gpu edge temperature is ${gput}"
read -p "what is your target temperature ?" target

if ! [[ $target =~ ^[0-9]+$ ]]; then
   echo "error: Not a number" >&2; exit 1
fi

if (( $target > $gput )); then
echo "nothing will bew done"
else
#loop fibonacci 
for t in 0 10 20 30 50 80; do
sleep $t
gput=$(sensors | grep "edge" | cut -d "+" -f 2 | cut -d "." -f 1)
fspeed=$(cat /opt/oc-amd/oc_start.txt | grep 'fspeed' | cut -d " " -f 3)
if [[ "${gput}" > $target ]]; then
deltatf=$(( ($gput - $target) * 10 ))
fspeedx=$(( $fspeed + $deltatf ))
if [[ ${fspeedx} > 210 ]]; then
	fspeedx=210
fi
echo $fspeedx
echo $fspeedx > ${path2card}/hwmon/hwmon*/pwm1
fi
done
echo "valeur finale a retenir : ${fspeedx}"
echo -n "Do you want to modify fan speed for next miner restart ? (Y/n)"
read answer
case $answer in
	[yY])
echo "$(awk '$1 ~ /fspeed$/ {$3 = 222}1' /opt/oc-amd/oc_start.txt)" > /opt/oc-amd/oc_start.txt
	;;
	[nN])
echo "Let's hope your card will survive those temperature"
	;;
	*)
echo "invalid input"
	;;
esac
fi

exit
