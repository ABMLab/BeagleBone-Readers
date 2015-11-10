#!/bin/bash


###################################################################################
# This script is prepared to setup BeagleBone Black devices for setting up a wifi #
# and creating an script to run the openbeacon_forwarder to send data packets to  #
# the specified data sink.                                                        #
###################################################################################
# Author: Mehdi Najafi (mnyorku@gmail.com)                                        #
#              ABM-Lab, York University , Toronto, ON, CANADA                     #
###################################################################################


# log file name
#LOGFILE="setup.log"

# assign the file descriptor 3 to the above LOG file
#exec 3> $LOGFILE

# Default text editor
TEDITOR=nano
#TEDITOR=gedit

HOME_DIR="/home/debian"
CUR_DIR="$(pwd)"
OPENBEACONNG_DIR="Code"
OPENBEACONNG_CLONE_DIR="openbeacon-mn"
OPENBEACONNG_URL="https://github.com/ABMLab/openbeacon-mn.git"
OPENBEACON_FW_DIR="openbeacon-mn/host/openbeacon-cape"
#OPENBEACONNG_CLONE_DIR="openbeacon-ng"
#OPENBEACONNG_URL="https://github.com/meriac/openbeacon-ng.git"
#OPENBEACON_FW_DIR="openbeacon-ng/host/openbeacon-cape"

# Specific Scripts
ABMLAB_SCR=ABMLABScript.sh
ABMLAB_SRV=ABMLABScript.service
ABMLABWIFI_SCR=ABMLABWiFiScript.sh
ABMLABWIFI_SRV=ABMLABWiFiScript.service
ABMLAB_SCR_DIR=/usr/bin
ABMLAB_SRV_DIR=/lib/systemd

# Extract the data sink from the current scripts
DEFAULTDATASINK=$(grep -F  "DATASINK=" $ABMLAB_SCR | cut -d= -f2)
DEFAULTDATASINKWIFI=$(grep -F  "DATASINK=" $ABMLABWIFI_SCR | cut -d= -f2)

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
	echo "This script must be run with super-user privileges. Try using \"sudo ./setup.sh\""
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

	NSTEP=0

	read -r -p "Proceed to system update and network tools setup -recommended for the new devices- [y/n]?" key
	if [ "$key" == 'y' ]; then
		# ------------------------------------------------------------------------------------------------------------------------------------------------------
		NSTEP=$[$NSTEP+1]
		echo ""
		echo "** Step $NSTEP: update the OS and install network utilities ... "
		echo ""
		sudo apt-get -y update
		sudo apt-get -y install network-manager
		sudo apt-get -y install net-tools
		sudo apt-get -y install libpcap-dev
	fi
	
	read -r -p "Proceed to wifi network setup -recommended for the new devices- [y/n]?" key
	if [ "$key" == 'y' ]; then
		# ------------------------------------------------------------------------------------------------------------------------------------------------------
		sudo bash ./wifi.sh -q
	fi

	# check if the box is online 
	# ------------------------------------------------------------------------------------------------------------------------------------------------------
	NSTEP=$[$NSTEP+1]
	echo ""
	echo "** Step $NSTEP: checking the internet availability ... "
	echo ""
	wget -q --spider http://google.com
	if [ $? -eq 0 ]; then
		echo "*** Online: an internet connection detected."
		ONLINE=1
	else
		echo "<!!!> Offline: no internet connection detected."
		ONLINE=0
	fi

	# check if the box is online again
	if [ $ONLINE -eq 0 ]; then
		echo "This script needs an internet connection to continue."
		echo "Check your connection and execute wifi.sh"
		echo "Script terminates as no internet connection exits."
		exit 1
	fi


	# ------------------------------------------------------------------------------------------------------------------------------------------------------
	NSTEP=$[$NSTEP+1]
	echo ""
	echo "** Step $NSTEP: getting and compiling openbeacon_forwarder ... "
	echo "Cloning openbeacon from $OPENBEACONNG_URL ..."
	rm -rf $HOME_DIR/$OPENBEACONNG_DIR /$OPENBEACONNG_CLONE_DIR
	[ ! -d $HOME_DIR/$OPENBEACONNG_DIR ] && mkdir -p $HOME_DIR/$OPENBEACONNG_DIR || :
	cd $HOME_DIR/$OPENBEACONNG_DIR
	git clone $OPENBEACONNG_URL
	cd $OPENBEACON_FW_DIR
	echo "Compiling openbeacon_forwarder..."
	make clean
	make
	cd $CUR_DIR

	# ------------------------------------------------------------------------------------------------------------------------------------------------------
	NSTEP=$[$NSTEP+1]
	echo ""
	echo "** Step $NSTEP: setting up $ABMLAB_SCR and $ABMLABWIFI_SCR scripts ... "
	
	echo "Change the data sink at $DEFAULTDATASINK in $ABMLAB_SCR script? (y/n)"
	#read -n1 -r -p "Press [y] to change or other key to continue:" key
	read  -r key
	echo ""
	if [ "$key" == 'y' ]; then
		echo "New data sink (format: $DEFAULTDATASINK):"
		read NEWDATASINK
		sudo sed "s/$DEFAULTDATASINK/\"$NEWDATASINK\"/g" ./$ABMLAB_SCR > ./tmp.sh && mv ./tmp.sh  $ABMLAB_SCR_DIR/$ABMLAB_SCR
	else
		sudo cp -f  ./$ABMLAB_SCR  $ABMLAB_SCR_DIR
	fi
	
	echo "Change the IP address at $DEFAULTDATASINKWIFI in $ABMLABWIFI_SCR script? (y/n)"
	#read -n1 -r -p "Press [y] to change or other key to continue:" key
	read  -r key
	echo ""
	if [ "$key" == 'y' ]; then
		echo "New IP address (format: $DEFAULTDATASINKWIFI):"
		read NEWDATASINK
		sudo sed "s/$DEFAULTDATASINKWIFI/\"$NEWDATASINK\"/g" ./$ABMLABWIFI_SCR > ./tmp.sh && mv ./tmp.sh $ABMLAB_SCR_DIR/$ABMLABWIFI_SCR
	else
		sudo cp -f  ./$ABMLABWIFI_SCR  $ABMLAB_SCR_DIR
	fi
		
	sudo chmod u+x $ABMLAB_SCR_DIR/$ABMLAB_SCR
	sudo chmod u+x $ABMLAB_SCR_DIR/$ABMLABWIFI_SCR
	
	# ------------------------------------------------------------------------------------------------------------------------------------------------------
	NSTEP=$[$NSTEP+1]
	echo ""
	echo "** Step $NSTEP installing and enabling systemd services for $ABMLAB_SCR and $ABMLABWIFI_SCR to run at boot."
	echo ""
	# create a service for those scripts
	sudo printf "[Unit]\nDescription=Run the ABM-Lab scripts\nAfter=syslog.target network.target\n\n" > $ABMLAB_SRV_DIR/$ABMLAB_SRV
	sudo printf "[Service]\nType=simple\nExecStart=$ABMLAB_SCR_DIR/$ABMLAB_SCR \n\n" >> $ABMLAB_SRV_DIR/$ABMLAB_SRV
	sudo printf "[Install]\nWantedBy=multi-user.target\n" >> $ABMLAB_SRV_DIR/$ABMLAB_SRV
	
	sudo printf "[Unit]\nDescription=Run the ABM-Lab scripts\nAfter=syslog.target network.target\n\n" > $ABMLAB_SRV_DIR/$ABMLABWIFI_SRV
	sudo printf "[Service]\nType=simple\nExecStart=$ABMLAB_SCR_DIR/$ABMLABWIFI_SCR \n\n" >> $ABMLAB_SRV_DIR/$ABMLABWIFI_SRV
	sudo printf "[Install]\nWantedBy=multi-user.target\n" >> $ABMLAB_SRV_DIR/$ABMLABWIFI_SRV

	cd /etc/systemd/system/
	sudo ln -f $ABMLAB_SRV_DIR/$ABMLAB_SRV  $ABMLAB_SRV
	sudo systemctl daemon-reload 
	sudo systemctl start $ABMLAB_SRV
	sudo systemctl enable $ABMLAB_SRV
	
	sudo ln -f $ABMLAB_SRV_DIR/$ABMLABWIFI_SRV  $ABMLABWIFI_SRV
	sudo systemctl daemon-reload 
	sudo systemctl start $ABMLABWIFI_SRV
	sudo systemctl enable $ABMLABWIFI_SRV
	
	cd $CUR_DIR
	
	echo "Setup is completed."

	restart_device 2

	echo "You may restart the box using \"sudo reboot\" to check if everything is in order."
fi
