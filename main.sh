echo "Started automatic Arch Linux installer
"

# 0. Inform user of environment variables to set
echo "STEP 1: Environment Variables Setup"

env_vars_req="TARGET_DRIVE"
env_vars_opt="WIFI_SID WIFI_PASS"
invalid_req_var=false
echo "$env_vars_req" | tr ' ' '\n' | while read i; do
	env_var=$(printenv $i)
	if [ "$env_var" = "" ]
	then
		echo " One or more required environment variables hasn't been set..."
		
		echo " You MUST set the following REQUIRED environment variables:"
		echo "$env_vars_req" | tr ' ' '\n' | while read i; do
			echo " - $i"
		done
		echo ""

		echo " You CAN set the following OPTIONAL environment variables:"
		echo "$env_vars_opt" | tr ' ' '\n' | while read j; do
			echo " - $j"
		done
		echo " Cancelling installation...
"
		exit # TODO: Seems like exit from inside the loop doesn't work...
	fi
done

# 1. Check network connection (ask if wifi is available, otherwise ethernet should auto connect)
echo "STEP 2: Network connection setup"
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
echo "STEP 3: Install disk selection (only 1 disk per installation supported)"
if [ "$TARGET_DRIVE" = "" ]
then
	echo " Which disk would you like to install to (WARNING: This disk will be wiped):"
	lsblk | grep disk | while read j; do	
		id=$(echo $j | awk '{print $1}')
		size=$(echo $j | awk '{print $4}')
		model=$(cat /sys/class/block/"$id"/device/model)
		echo " - $id ($size): $model"
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
