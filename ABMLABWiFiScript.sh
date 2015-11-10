#!/bin/bash
# Script to monitor and restart wireless access point when needed

# log file name
LOGFILE="/home/debian/abmlab-wifi-log.txt"

# assign the file descriptor 2 to a LOG file
exec 3>> $LOGFILE

# default data sink
#DATASINK="130.63.38.107"
DATASINK="www.google.com"

# get an active wlan
WLAN=$(/sbin/ifquery -l | grep wlan)


#Maximum percent packet loss before a restart
maxPloss=60

#network state
netdown=0

check_current_status()
{
	# First make sure we can resolve google, otherwise 'ping -w' would hang
	if $(host -W5 www.google.com > /dev/null 2>&1); then
		# Second make sure we can resolve data sink, otherwise 'ping -w' would hang
		if $(host -W5 $DATASINK > /dev/null 2>&1); then
			# Initialize to a value that would force a restart
			# (just in case ping gives an error and ploss doesn't get set)
			ploss=101
			# now ping data sink for 10 seconds and count packet loss
			ploss=$(ping -q -w10 $DATASINK | grep -o "[0-9]*%" | tr -d %) > /dev/null 2>&1
			if [ "$1" -ne "0" ] ; then
				echo "$(date) : Network connection is up and $DATASINK is reachable with ($ploss%) packet loss." >&3
			fi
			if [ "$ploss" -gt "$maxPloss" ]; then
				echo "$(date) : Network connection is up and $DATASINK is reachable but packet loss ($ploss%) is higher than expected ($maxPloss%)." >&3
				netdown=1
				return 1
			fi
			netdown=0
			return 0
		fi
		echo "$(date) : Network connection is up but $DATASINK is unreachable." >&3
		netdown=2
		return 2
	fi
	echo "$(date) : Network connection is down or $DATASINK is unreachable, restarting the network may be useful." >&3
	netdown=3
	return 3
}


restart_networking()
{
	#make a note in log
	echo "$(date) : Restarting the network to solve the issues ..." >&3

	sudo /sbin/ifdown $WLAN
	sleep 1     #give it a few seconds to complete
	sudo /sbin/ifup $WLAN

	check_current_status 2

        # Add any commands need to get network back up and running
        #/etc/init.d/networking restart
        #only needed if your running a wireless ap
        #/etc/init.d/dhcp3-server restart 
}


echo "=================================================================================" >&3
echo "$(date) : ABM-LAB @ York University startup:" >&3

sleep 5
check_current_status 2
if [$? -ne 0]; then
	restart_networking
fi

while true; do
	check_current_status $netdown
	if [$? -ne 0]; then
		restart_networking
	fi

	sleep 30 #check again in 30 seconds
done

echo "$(date): Terminated." >&3


########################################################################################
# NOTE: without ping which is more faster
#wget -q --spider http://google.com
#if [ $? -eq 0 ]; then
#    echo "Online"
#else
#    echo "Offline"
#fi


########################################################################################
## Bring all wifi interfaces down.
## Identify wifi interfaces as rows from standard output of iwconfig (NOT standard
## error, those are non-wifi interfaces) which start without whitespace.
#iwconfig 2> /dev/null | grep -o '^[[:alnum:]]\+' | while read x; do ifdown $x; done
## Bring all wifi interfaces up.
#iwconfig 2> /dev/null | grep -o '^[[:alnum:]]\+' | while read x; do ifup $x; done
