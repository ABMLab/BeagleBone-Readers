#!/bin/bash

# log file name
LOGFILE="/home/debian/abmlab-log.txt"

# assign the file descriptor 3 to a LOG file
exec 3>> $LOGFILE

DATASINK="130.63.38.107 2342"

RETRIES=0

echo "=======================================================================================" >&3
echo "$(date): ABM-LAB @ York University startup:" >&3
echo "Sleeping for 5 seconds ... Data sink IP: $DATASINK" >&3

sleep 5

echo "---------------------------------------------------------------------------------------" >&3
echo "*** Network Device Information [eth1]  ***"  >&3
netstat -i | grep -q eth1 && /sbin/ifconfig eth1 >&3 || echo "eth1 is not installed" >&3

echo "*** Wireless Device [wlan0]  ***"  >&3
netstat -i | grep -q wlan0 && /sbin/ifconfig wlan0 >&3 && /sbin/ifquery wlan0 >&3 || echo "wlan0 is not installed$"

echo "*** Wireless Device [wlan1]  ***"  >&3
netstat -i | grep -q wlan1 && /sbin/ifconfig wlan1 >&3 && /sbin/ifquery wlan1 >&3 || echo "wlan1 is not installed$"

echo "*** All Network Interfaces Stats ***" >&3

netstat -i >&3
echo "----------------------------------------------------------------------------------------" >&3

# bash infinte while loop
while true
do
if [ $RETRIES -gt 0 ]; then
echo  "    $(date): waiting 5 sec. then re-starting [$RETRIES] openbeacon_forwarder." >&3
else
echo  "    $(date): waiting 5 sec. then starting openbeacon_forwarder." >&3
fi

sleep 5

let RETRIES=RETRIES+1

# /home/debian/Code/openbeacon-ng/host/openbeacon-cape/openbeacon_forwarder $DATASINK >&3
sudo /home/debian/Code/openbeacon-mn/host/openbeacon-cape/openbeacon_forwarder $DATASINK >&3

done

echo "$(date) meeshun comprete." >&3

