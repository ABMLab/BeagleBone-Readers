#!/bin/bash


###################################################################################
# This script is prepared to setup BeagleBone Black devices for setting up a wifi #
# connection.                                                                     #
###################################################################################
# Author: Mehdi Najafi (mnyorku@gmail.com)                                        #
#              ABM-Lab, York University , Toronto, ON, CANADA                     #
###################################################################################


# syntax
# if run without arguments, will prompt
# if run with arguments, you need
# wifi [essid] [rate] [WEPkey]
#  WEPkey can be "none" if you don't want to be prompted


# log file name
#LOGFILE="wifi.log"

# assign the file descriptor 3 to the above LOG file
#exec 3> $LOGFILE

# Default text editor
TEDITOR=nano
#TEDITOR=gedit

# Network Vars
INTERFACES=/etc/network/interfaces
WPA_SUPPLICANT=/etc/wpa_supplicant/wpa_supplicant.conf
UENV=/boot/uEnv.txt
EMMC_OVERLAY="$(grep -F "emmc-overlay"  /boot/uEnv.txt)"

IFCONFIG="/sbin/ifconfig"
IWLIST="/sbin/iwlist"
IWCONFIG="/sbin/iwconfig"
DHCLIENT="/sbin/dhclient"

WLAN="$($IWCONFIG 2>&1 | grep -o 'wlan[0-9]')"


restart_device()
{
	local key='y'
	echo "Setup will reboot the device."
	if [ $1 -eq 1 ] ; then
		echo "Run this script again after the next boot."
		while [  "$key" != 'n' ]
		do
			read -r -p "Wait...? [n]" key
		done
		sudo reboot
	fi
	if [ $1 -eq 2 ] ; then
		read -r -p "If you plan to reboot later press [n] or any other key to reboot now:" key
		if [ "$key" != 'n' ]; then
			sudo reboot
		fi
	fi
}


list_available_wifis()
{
	local a=0
	local b=0
	local x=1
	while read line; do
		case $line in
			*Cell* )
				if [ $b -eq 0 ]; then
					a=$((a + 1))
				fi
				b=0
				;;
			*ESSID* )
				essid[$a]=${line#*"ESSID*"}
				if [ ${line#*"ESSID:"} == "\"\"" ]; then
					b=1
				fi
				;;
			*Group* )
				group[$a]=${line#*"Group*"};;
			*Authentication* )
				athen[$a]=${line#*"Authentication*"};;
			*Encryption* )
				encry[$a]=${line#*"Encryption*"};;
		esac
	done  < <(sudo $IWLIST $WLAN scan) 

	if [ $b -eq 1 ]; then
		a=$((a - 1))
	fi

	echo "$(date) : $a WiFi networks found:"
	while [ $x -lt ${#essid[@]} ];do
		echo "---------------------------------------"
		echo "${essid[$x]}"
		echo "${encry[$x]}"
		echo "${group[$x]}"
		echo "${athen[$x]}"
		(( x++ ))
	done | more
}


# Make sure only under root permission can run the script
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run with super-user privileges. Try using \"sudo ./setup.sh\""
	exit 1
fi

if [ "$1" = "-q" ] ; then
	key='y'
	shift
else
	echo "---------------------------------------------------------------"
	echo "Setting up Wifi - BeagleBone Black for ABM-Lab,York University"
	echo "---------------------------------------------------------------"

	echo "Make sure that this script is running on the correct device."
	echo ""
	read -r -p "To continue press [y] or any other key to cancel ..." key
fi

if [ "$key" == 'y' ]; then
	# y pressed, do something

	NSTEP=0

	# check if the box is online 
	# ------------------------------------------------------------------------------------------------------------------------------------------------------
	NSTEP=$[$NSTEP+1]
	echo ""
	echo "** Step $NSTEP: check the internet availability ... "
	echo ""
	wget -q --spider http://google.com
	if [ $? -eq 0 ]; then
		echo "*** Online: an internet connection detected."
		ONLINE=1
	else
		echo "<!!!> Offline: no internet connection detected."
		ONLINE=0
	fi
	
	# ------------------------------------------------------------------------------------------------------------------------------------------------------
	NSTEP=$[$NSTEP+1]
	echo ""
	echo "** Step $NSTEP: checking and setting up wlan ... "
	echo ""
	if [ "$WLAN" = "" ]; then
		if [[ $EMMC_OVERLAY = \#* ]]; then
			sudo sed "s/$EMMC_OVERLAY/${EMMC_OVERLAY:1}/g" $UENV > tmp.sh && mv tmp.sh  $UENV
			#rm ./tmp.sh
			echo "** No wlan detected."
			restart_device 1
		fi
	fi
	
	# ------------------------------------------------------------------------------------------------------------------------------------------------------
	NSTEP=$[$NSTEP+1]
	echo ""
	echo "** Step $NSTEP: checking $WLAN ... "
	echo ""
	
	# check wlan index setup
	# get an active wlan
	if [ "$WLAN" != "wlan1" ]; then
		echo "Found $WLAN instead of wlan1 ... changing the corresponding file."
		sudo sed "s/wlan1/$WLAN/g" interfaces > tmp && mv tmp interfaces
		sudo cp -f interfaces $INTERFACES
		#rm ./tmp
	fi
		
	# first just bring up the interface
	$IFCONFIG $WLAN up 2> /dev/null
	if [ $? -ne 0 ]
	then
		echo "Cannot execute: $IFCONFIG $WLAN up"
		exit
	fi  

	# ------------------------------------------------------------------------------------------------------------------------------------------------------
	NSTEP=$[$NSTEP+1]
	echo ""
	echo "** Step $NSTEP: setup essid, rate, WEP key ... "
	echo ""
	# get the essid
	if [ "$1" = "" ]; then
		# ask if the user wants a list
		echo -n "Would you like a list? [y]"
		read PROMPT
		case "$PROMPT" in
				[yY]	) list_available_wifis ;;
				""	) list_available_wifis ;;
#				[yY]	) $IWLIST $WLAN scanning | more;;
#				""	) $IWLIST $WLAN scanning | more;;
				*     ) echo "OK, find it yourself then";;
		esac
		# prompt for the rest
		echo -n "ESSID (name?):"
			read ESSID
	else
			ESSID="$1"
	fi

	# get the rate
#	if [ "$2" = "" ]; then
#		echo -n "rate [54M]:"
#		read RATE
#		if [ "$RATE" = "" ]; then
#			RATE="54M"
#		fi
#	else
#		RATE="$2"
#	fi

	# get the WEPkey
	if [ "$3" = "" ]; then
		echo -n "WEPkey [none]:"
		read WEP
	else
		WEP="$3"
		if [ "$WEP" = "none" ];  then
			WEP=""
		fi
	fi

	
	# start running the commands NOW
	$IWCONFIG $WLAN essid "$ESSID" 2> /dev/null
	if [ $? -ne 0 ]; then
		echo "Cannot $IWCONFIG $WLAN essid $ESSID"
#		exit
	fi

#	$IWCONFIG $WLAN rate "$RATE" 2> /dev/null
#	if [ $? -ne 0 ]; then
#		echo "Cannot $IWCONFIG $WLAN rate $RATE"
#		exit
#	fi

	# now set the key, if necessary
	if [ "$WEP" != "" ]; then
		$IWCONFIG $WLAN key s:"$WEP" 2> /dev/null
		if [ $? -ne 0 ] ;then
			echo "Cannot $IWCONFIG $WLAN key s:$WEP"
#			exit
		fi
	fi

	$DHCLIENT $WLAN 2> /dev/null
	if [ $? -ne 0 ]; then
		echo "Cannot $DHCLIENT $WLAN"
#		exit
	fi

	# ------------------------------------------------------------------------------------------------------------------------------------------------------
	NSTEP=$[$NSTEP+1]
	echo ""
	echo "** Step $NSTEP: install network scripts ... "
	echo ""

	echo "##### wpa_supplicant configuration file ###############################" > tmp
	echo "ctrl_interface=DIR=/var/run/wpa_supplicant" >> tmp
	echo "ctrl_interface_group=netdev" >> tmp
	echo "update_config=1" >> tmp
	echo "eapol_version=1" >> tmp
	echo "ap_scan=1" >> tmp
	echo "fast_reauth=1" >> tmp
	echo "" >> tmp

	key='n'
	if [ "$WEP" = "" ]; then
		read -r -p "Use any open-access wifi for future? [y/n]" key
		if [ "$key" == 'y' ]; then
			# y pressed, do something
			echo "# Plaintext connection (no WPA, no IEEE 802.1X)" >> tmp
			echo "network={" >> tmp
			echo "	key_mgmt=NONE" >> tmp
			echo "}" >> tmp
		fi
	fi
	if [ "$key" == 'n' ]; then
		echo "# Simple case: WPA-PSK, PSK as an ASCII passphrase, allow all valid ciphers" >> tmp
		echo "network={" >> tmp
		echo "	ssid=\"$ESSID\"" >> tmp
		if [ "$WEP" != "" ]; then
			echo "	psk=\"$WEP\"" >> tmp
		else
			echo "	key_mgmt=NONE" >> tmp
		fi
		#echo "	priority=5" >> tmp
		echo "}" >> tmp
	fi
	echo "" >> tmp
	
	cat wpa_supplicant.conf  >> tmp
	sudo mv -f tmp $WPA_SUPPLICANT

	# check if the box is online again
	wget -q --spider http://google.com
	if [ $? -ne 0 ]; then
		echo "<!!!> Still Offline: no internet connection detected."
		echo "This script needs an internet connection to continue. Check your connection and run this script again."
		echo "You may check that Wireless LAN is not blocked using rfkill."
		echo "You may also need to edit /etc/network/interfaces or /etc/wpa_supplicant/wpa_supplicant.conf"
		read -r -p "Do you want to edit them? [y/n]" key
		if [ "$key" == 'y' ]; then
			sudo $TEDITOR /etc/network/interfaces
			sudo $TEDITOR /etc/wpa_supplicant/wpa_supplicant.conf
			restart_device 1
		fi
	fi


	# ------------------------------------------------------------------------------------------------------------------------------------------------------
	echo "WiFi setup is completed."

	restart_device 2

	echo "You may restart using \"sudo reboot\" to check if wifi connection is working."
fi
