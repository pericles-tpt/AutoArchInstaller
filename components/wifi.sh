#!/bin/sh

ifaces=$(ip addr | grep ': <' | sed 's/://' | awk '{print $2}' | tr -d ':')

fail_iface=0
total_iface=0
WIFI_SID=$1
WIFI_PASS=$2

if [ "$WIFI_SID" = "" ] || [ "$WIFI_PASS" = "" ]
then
	echo "WARNING: WiFi credentials not set, if you wish to setup wifi, restart this script"
else
	for i in $ifaces; do
		total_iface=$((total_iface+1))
		con_resp=$(iwctl --passphrase=$WIFI_PASS station $i connect $WIFI_SID | grep 'not found\|Operation failed\|Argument format is invalid\|Invalid network name')
		if [ "$con_resp" != "" ]
		then
			a="not found"
			b="Invalid network name"
			if [ -z "${con_resp##*$a*}" ]
			then
				echo "FAILED: Network device not found for $i" 
			elif [ -z "${con_resp##$b*}" ]
			then
				echo "FAILED: SID not found on $i"
			else
				echo "FAILED: Password is invalid on $i"
			fi
			fail_iface=$((fail_iface+1))
		else
			echo "SUCCESS: Connected to interface $i"
			break
		fi
	done

	# Check how many of the network interfaces failed
	if [ $fail_iface -lt $total_iface ]
	then
		success_iface=$((total_iface-fail_iface))
		echo "Success on $success_iface / $total_iface network interfaces"
		echo "Sleeping for 30s, to give time to connect..."
		sleep 30
		ping -c 3 linux.org
	else
		echo "Failure on ALL network interfaces"
	fi
fi

if [ $fail_iface -eq $total_iface ]
then
	echo "WARNING: WiFi credentials have not been set OR WiFI setup failed, either restart the script and set them OR
	complete the next ethernet connection step
	"
	echo "Plug in your ethernet cable to connect to the internet via ethernet, click ENTER when you're done"
	read -r ETH_CONNECTED
	echo "Waiting 10s before 'ping' test on ethernet..."
	sleep 10

	con_test=$(ping -c 3 linux.org 2>&1 | grep 'cannot' | wc -l)
	if [ $con_test -gt 0 ]
	then
		echo "FAILED: Unable to connect to ethernet"
		exit 1
	else
		echo "SUCCESS: Successfully connect to ethernet!"
	fi
fi



