#!/bin/bash


###############################################################################
# The script is prepared to change the BeagleBone Black devices DATA SINK and #
# and editing the corresponding scripts to send data packets to the specified #
# specified data sink.                                                        #
###############################################################################
# Author: Mehdi Najafi (mnyorku@gmail.com)                                    #
#              ABM-Lab, York University , Toronto, ON, CANADA                 #
###############################################################################


# log file name
#LOGFILE="setup.log"

# assign the file descriptor 3 to the above LOG file
#exec 3> $LOGFILE

# Specific Scripts
ABMLAB_SCR=ABMLABScript.sh
ABMLABWIFI_SCR=ABMLABWiFiScript.sh
ABMLAB_SCR_DIR=/usr/bin

# Extract the data sink from the current scripts
DEFAULTDATASINK=$(grep -F  "DATASINK=" $ABMLAB_SCR_DIR/$ABMLAB_SCR | cut -d= -f2)
DEFAULTDATASINKWIFI=$(grep -F  "DATASINK=" $ABMLAB_SCR_DIR/$ABMLABWIFI_SCR | cut -d= -f2)

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


# Make sure only under root permission can run the script
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run with super-user privileges. Try using \"sudo ./chsink.sh\""
	exit 1
fi

echo "---------------------------------------------------------------"
echo "Setting up BeagleBone Black for test at ABM-Lab York University"
echo "---------------------------------------------------------------"
echo "Make sure that this script is running on the correct device."
echo ""
read -r -p "To continue press [y] or any other key to cancel ..." key

if [ "$key" == 'y' ]; then
	# y pressed, do something

	echo "Change the data sink at $DEFAULTDATASINK in $ABMLAB_SCR script? (y/n)"
	#read -n1 -r -p "Press [y] to change or other key to continue:" key
	read  -r key
	echo ""
	if [ "$key" == 'y' ]; then
		echo "New data sink (format: $DEFAULTDATASINK):"
		read NEWDATASINK
		sudo sed "s/$DEFAULTDATASINK/\"$NEWDATASINK\"/g" $ABMLAB_SCR_DIR/$ABMLAB_SCR > ./tmp.sh && mv ./tmp.sh  $ABMLAB_SCR_DIR/$ABMLAB_SCR
	fi

	echo "Change the IP address at $DEFAULTDATASINKWIFI in $ABMLABWIFI_SCR script? (y/n)"
	#read -n1 -r -p "Press [y] to change or other key to continue:" key
	read  -r key
	echo ""
	if [ "$key" == 'y' ]; then
		echo "New IP address (format: $DEFAULTDATASINKWIFI):"
		read NEWDATASINK
		sudo sed "s/$DEFAULTDATASINKWIFI/\"$NEWDATASINK\"/g" $ABMLAB_SCR_DIR/$ABMLABWIFI_SCR > ./tmp.sh && mv ./tmp.sh $ABMLAB_SCR_DIR/$ABMLABWIFI_SCR
	fi
		
	restart_device 2

	echo "You may restart the box using \"sudo reboot\" to check if everything is in order."
fi
