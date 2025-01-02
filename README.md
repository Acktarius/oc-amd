# oc-amd

## this script is delivered “as is” and I deny any and all liability for any damages arising out of using this script  
(tested on Ubuntu 22.04, and amdgpu driver 5.4.50403-1, only the card for which values are provided are supported)

the script aim to set the performance mode to manual, to limit the power, to lower mem frequency, and increase the fan speed.  
if you want to increase your core clock, follow the procedure indicated in last section.

## Install
ideally place in the /opt folder

`cd /opt/conceal-toolbox`

```
sudo git clone https://github.com/Acktarius/oc-amd.git
```
`cd oc-amd`

`sudo chmod 755 oc-amd.sh`


oc-amd is a bash script which can be launch as a service to setup overclock pre mining operation.

## Use
### for a one card computer, CCX-BOX style
`sudo ./oc-amd.sh`  

the value within oc_start_*.txt file will be used to set performance mode, pl, mem , fan

when done:  
`sudo ./oc-amd.sh reset`
###

### for a rig  
`sudo ./oc-amd-rig.sh`  
This script will go through all your cards and if find an oc_start_*.txt file will apply it.

## You can also install a graphical launcher applications:
```bash
sudo ./shortcut_creator.sh
```
This will create an easy-to-use launcher that can apply or reset your overclock settings.
And set up the required polkit policy for elevated privileges.


---

## Modify core clock  
*this is only taken care of by the rig script, follow the next steps if you wish to change those values manually*  
### reference : [https://wiki.gentoo.org/wiki/AMDGPU](https://wiki.gentoo.org/wiki/AMDGPU)  
*exemple for card0, as root :*  
 ```
 cat /sys/class/drm/card0/device/pp_od_clk_voltage
 ```
 get the OD_SCLK value, you want to change, let's say the one at line 1 :  
 ```
 echo 's 1 2410' > /sys/class/drm/card0/device/pp_od_clk_voltage
 ```
 commit your value :  
 ```
 echo 'c' > /sys/class/drm/card0/device/pp_od_clk_voltage
```
if you wish to revert your value :  
```
echo 'r' > /sys/class/drm/card0/device/pp_od_clk_voltage
```