echo "## Started automated Arch Linux installer ##
"

# 1. Prompt user for each required environment variable (if not already set)
# 1.1. Get WiFi credentials (OPTIONAL)
echo "STEP 1: Prompts for any unspecified environment variables"
echo "1.1. Do you want to setup a wi-fi connection (for the installation)? [Y/n]"
read -r USE_WIFI
if [ "$USE_WIFI" = "Y" ] | [ "$USE_WIFI" = "y" ] | [ "$USE_WIFI" = "" ]
then
	if [ "$WIFI_SID" = "" ]
	then
		echo "1.1.1: Please specify your WIFI SID below:"
		while [ "$WIFI_SID" = "" ]; do
			read -r SID
			export "WIFI_SID=$SID"
			if [ "$WIFI_SID" = "" ]
			then
				echo "! No value provided for wifi sid, please specify:"
			fi
		done
	fi

	if [ "$WIFI_PASS" = "" ]
	then
		# TODO: This section is repeated, figure out how to write POSIX shell functions
		echo "1.1.2: Please specify your WIFI password below:"
		while [ "$WIFI_PASS" = "" ]; do
			read -r PASS
			export "WIFI_PASS=$PASS"
			if [ "$WIFI_PASS" = "" ]
			then
				echo "! No value provided for wifi password, please specify:"
			fi
		done
	fi
fi

# 1.2. Get the target drive
if [ "$TARGET_DRIVE" = "" ]
then
	echo ""
	echo "1.2: Which disk would you like to install to (e.g. 'sda', 'sdb', 'nvme0', etc
	WARNING: This disk will be wiped:"
	lsblk | grep disk | while read j; do	
		id=$(echo $j | awk '{print $1}')
		size=$(echo $j | awk '{print $4}')

		# Used
		diskInfo=$(fdisk -l /dev/"$id")
		totalSizeBytes=$(echo $diskInfo | head -n 1 | awk '{print $4}')
		usedSizeBytes=0
		fdisk -l /dev/$id | grep "^/dev/$id[\d]*" | awk '{print $5}' | while read k; do
			partSize=0
			num=$(echo $k | sed 's/.$//')
			if [ $(echo "${k: -1}") = "B" ];
			then
				$((partSize=$num))
			else if [ $(echo "${k: -1}") = "K" ];
			then
				$((partSize=$num*1024))
			else if [ $(echo "${k: -1}") = "M" ];
			then
				$((partSize=$num*1024*1024))
			else if [ $(echo "${k: -1}") = "G" ];
				$((partSize=$num*1024*1024*1024))
			else if [ $(echo "${k: -1}") = "T" ];
				$((partSize=$num*1024*1024*1024*1024))
			else if [ $(echo "${k: -1}") = "P" ];
				$((partSize=$num*1024*1024*1024*1024*1024))
			else
				echo "Sorry we can't handle EXABYTES of storage..."
				exit 1
			$((usedSize=usedSize+partSize))
		done
		echo $((usedSize/totalSize))
		model=$(cat /sys/class/block/"$id"/device/model)
		echo "* $id ($size): $model"
	done 

	TARGET_VALID=0
	while [ $TARGET_VALID == 0 ]; do
		read -r TARGET_DRIVE
		TARGET_VALID=$(fdisk -l /dev/$TARGET_DRIVE 2>&1 | grep -v 'cannot' | wc -l)
		if [ $TARGET_VALID == 0 ]
		then
			echo " Invalid disk: Type an id from the list above should look similar to 'sdX' or 'nvmeX'"
		fi
	done 
fi

# 1.3. Get the user's desired partition scheme
# LVM?
# Encryption?
# Separate /home and /

# 1.4. Get hardware specific drivers

# 1.5. Ask for how large they'd like swap to be

# 2. Check network connection (ask if wifi is available, otherwise ethernet should auto connect)
echo "
STEP 2: Network connection setup"
sleep 1 # Change this BACK TO 10 later
is_disconnected=$(ping -c 3 linux.org 2>&1 | grep "Temporary failure" | wc -l)
if [ $is_disconnected == 1 ]
then
	echo " NOT CONNECTED TO INTERNET: Attempting automatic wi-fi setup now if you DON'T have wi-fi plug in ethernet now"
	chmod +x ./components/wifi-setup.sh
	sh ./components/wifi-setup.sh
else
	echo " CONNECTED TO INTERNET: Continuing with installation..."
fi 

# 2. Partition disk for boot, root (lvm and encryption?)
echo "
STEP 3: Install disk selection (only 1 disk per installation supported)"

echo $TARGET_DRIVE
# 3. Generate the `fstab` file

# 4. Install packages to installation target

# 5. arch-chroot into environment (could this be a problem?)

# 5a. Install packaged (could be done with pacstrap

# 5b. Start services

# 5c. Edit build flags in mkinitcpio

# 5d. Locale-gen

# 5e. Set root passwd

# 5f. Create users

# 5g. Install sudo and edit `visudo`

# 5h. Install grub and setup boot files

# 5i. Setup swap

# 6. Ask about any specific architecture drivers / microcode (intel/amd microcode), (intel/amd (same) or nvidia gpu drivers)
