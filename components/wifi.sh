ifaces=$(ip addr | grep ': <' | sed 's/://' | awk '{print $2}' | tr -d ':')

echo "What is the SID of your WIFI network (enter nothing to skip WIFI setup)?"
read -r NETWORK
if [ "$NETWORK" = "" ]
then
	echo "Exiting WIFI setup..."
	exit
fi

echo "What is the network password?"
read -r PASSWORD

fail_iface=0
total_iface=0
for i in $ifaces; do
	total_iface=$((total_iface+1))
	con_resp=$(iwctl --passphrase=$PASSWORD station $i connect $NETWORK | grep 'not found\|Operation failed\|Argument format is invalid\|Invalid network name')
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
