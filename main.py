import archinstall, getpass, urllib2, sleep, subprocess

# FUNCTIONS
def test_internet_connection(num_retries, timeout_seconds):
    connection_success = False
    for i in range(num_retries):
        # SOURCE: The below try/except block to test internet connection was found here:
        #         https://stackoverflow.com/a/3764660
        try:
            urllib2.urlopen('https://archlinux.org/', timeout=timeout_seconds)
            connection_success = True
        except urllib2.URLError as err: 
            connection_success = False
        sleep(1)
    return connection_success

def prompt_input(prompt_msg, value_key, allow_quit = False):
    sure = False
    while (not sure):
        value = input(prompt_msg)
        if allow_quit and value == 'q':
            break
        confirm = input(f"The {value_key} you provided is '{value}', are you sure? [Y/n]")
        sure    = (confirm.lower() == 'y')
    return value

print('''## Started automated Arch Linux installer ##
This script uses a combination of:
    The existing `archinstall` python module
    Some custom scripts for tasks like trying to connect to WiFi interfaces''')

# 1. Prompt user for each required environment variable (if not already set)
# 1.1. Get WiFi credentials (OPTIONAL)
print("1.0. Network Connection Setup")
connection_success = test_internet_connection(3, 5)

if not connection_success:
    print("Failed to connect to the internet...")
    use_wifi = input("1.1. Do you want to setup a wi-fi connection (for the installation)? [Y/n]")
    if use_wifi.lower() == 'y':
        prompt_msg = "1.1.1. What is your WiFi SID (type 'q' to cancel WiFi setup)?"
        wifi_sid = prompt_input(prompt_msg, "SID", True)

        prompt_msg = "1.1.2. What is your WiFi Password (type 'q' to cancel WiFi setup)?"
        wifi_pass = prompt_input(prompt_msg, "Password", True)

        if wifi_sid != 'q' and wifi_pass != 'q':
            subprocess.call(['sh', './components/wifi-setup.sh', wifi_sid, wifi_pass])
        else:
            print("Unable to access the internet over a wired or wireless interface, exiting...")
            exit(1)

disk_options = archinstall.all_blockdevices()
# 1.2. Get the target drive
if [ "$TARGET_DRIVE" = "" ]
then
	echo ""
	echo "1.2: Which disk would you like to install to (e.g. 'sda', 'sdb', 'nvme0', etc):"

	# Show user the available disks, with additional info to help them identify the right one
	./components/disk-options.sh

	TARGET_VALID=0
	while [ $TARGET_VALID == 0 ]; do
		read -p "> " TARGET_DRIVE
		TARGET_VALID=$(fdisk -l /dev/$TARGET_DRIVE 2>&1 | grep -v 'cannot' | wc -l)
		if [ $TARGET_VALID == 0 ]
		then
			echo " Invalid disk: Type an id from the list above should look similar to 'sdX' or 'nvmeX'"
		fi
	done 
fi

# 1.3 Get the partition scheme
# Use a string to define paritioning:
# e.g. 1 1 1 / 30% /boot 768M 
# Args as follows:
# * WHOLE/REMAINING(0,1)
# * USE_LVM(0,1)
# * USE_ENCRYPTION(0,1)
# * '/' (fat|ext3|ext4) (1 -> 100% OR nM OR nG) ext4/ext3/zfs/etc
# * '/boot' (fat) (1 -> 10% OR nM) fat
# * optionally more partitions...
PART_VALID=0
if [ "$PARTITION_SCHEME" != "" ]
then
	requiredRx="[0,1]\s[0,1]\s[0,1]\s(\/)\s(fat|ext4|ext3)\s([1-9][0-9]?%|100%|\d{3}[M,G])\s(\/boot)\s(fat)\s([1-9]?%|\d{3}[M])"
	optionalPartitionsRx="((\s)(\/([a-z]{1,20}))+(\s)(fat|ext4|ext3)\s([1-9][0-9]?%|100%|\d{3}[M,G]))"
	rx="^""$requiredRx""$optionalPartitionsRx*""$"
	PART_VALID=$(echo "$PARTITION_SCHEME" | grep \'$rx\' | wc -l)
fi

# If the partition scheme is not valid OR not specified we must ask all partitioning related questions
if [ $PART_VALID == 0 ]
then
	echo ""
	WHOLE_REMAINING=2
	while [ $WHOLE_REMAINING != 0 ] && [ $WHOLE_REMAINING != 1 ]; do
		echo "1.3.1 Would you like to wipe the WHOLE drive or just use REMAINING capacity?"
		echo "(0) WHOLE drive"
		echo "(1) REMAINING capacity"
		read -p "> " WHOLE_REMAINING
		if [ $WHOLE_REMAINING != 0 ] && [ $WHOLE_REMAINING != 1 ]
		then
			echo " Invalid input: You must provide either \"0\" or \"1\""
		fi
	done

	USE_LVM=2
	while [ $USE_LVM != 0 ] && [ $USE_LVM != 1 ]; do
		echo "1.3.2 Would you like to use LVM for partitioning (alternative is standard partitioning)?"
		echo "(0) Use standard partitioning"
		echo "(1) Use LVM"
		read -p "> " USE_LVM
		if [ $USE_LVM != 0 ] && [ $USE_LVM != 1 ]
		then
			echo " Invalid input: You must provide either \"0\" or \"1\""
		fi
	done

	USE_ENCRYPTION=2
	while [ $USE_ENCRYPTION != 0 ] && [ $USE_ENCRYPTION != 1 ]; do
		echo "1.3.3 Would you like to encrypt your non-boot partitions/LV?"
		echo "(0) DON'T encrypt partitions"
		echo "(1) Encrypt partitions"
		read -p "> " USE_ENCRYPTION
		if [ $USE_ENCRYPTION != 0 ] && [ $USE_ENCRYPTION != 1 ]
		then
			echo " Invalid input: You must provide either \"0\" or \"1\""
		fi
	done
else
	echo "WIP: We haven't finished this branch yet, support to come"
	exit
	# Deconstruct partition scheme into arguments
fi


# 4. Partitions for which directories, how many
# 	Minimally need root but can have more
partitionStr=""
ROOT_SPECIFIED=0
while [ $ROOT_SPECIFIED == 0 ]; do
	echo "Please specify the desired size (in GiB) of your root partition"
	read -p "> " ROOT_SIZE
done

#	4.1. Keep prompting the user for more partitions
# WARNING: This just checks that the path is of the correct structure (i.e. matches regex "^\/[a-z]+$")
#		   but it doesn't 'sanity' check it, i.e. /asjkajsdh will be accepted
ALL_PARTITIONS_DEFINED=0
while [ $ALL_PARTITIONS_DEFINED == 0 ]; do
	echo "Would you like to create additional partitions (e.g. /home, /usr, etc)? [Y/n]"
	read -p "> " NEW_PART
	if [ "$NEW_PART" = "Y" ] | [ "$NEW_PART" = "y" ] | [ "$NEW_PART" = "" ]
	then
		NEW_PATH=""
		while [ $(echo "$NEW_PATH" | grep \'$^\/[a-z]+$\' | wc -l) == 0] && ["$NEW_PATH" != "QUIT" ]; do
			echo "What 'path' would you like to map to your new partion (must be a '/' followed by [a-z]+, e.g. /home)?"
			echo "NOTE: Type 'QUIT' to cancel creating new partitions"
			read -p "> " NEW_PATH
		done

		if [ "$NEW_PATH" = "QUIT" ]
		then
			ALL_PARTITIONS_DEFINED=1
		else 
			NEW_SIZE=""
			while [ $(echo "$NEW_SIZE" | grep \'$\d+^\' | wc -l) == 0] && ["$NEW_SIZE" != "QUIT" ]; do
				echo "What size would you like your '$NEW_PATH' partition to be (in GiB)?"
				echo "NOTE: Type 'QUIT' to cancel creating new partitions"
				read -p "> " NEW_SIZE
			done
			if [ "$NEW_SIZE" = "QUIT" ]
			then
				ALL_PARTITIONS_DEFINED=1
			else
		fi
	else
		ALL_PARTITIONS_DEFINED=1
	fi
done

# 1.3. Get the user's desired partition scheme
# LVM?
# Encryption?
# Separate /home and /

# 1.4. Get hardware specific drivers

# 1.5. Ask for how large they'd like swap to be
if [ "$SWAP_SIZE" = "" ]
then
	echo "1.5.1 Please specify the size of your SWAP partition below (e.g. 20G, 300M, etc):"

	# Is swap greater than remaining space? Not valid
	# Is swap greater than RAM? Ask if they're sure

	SWAP_VALID=0
	while [ $SWAP_VALID == 0 ]; do
		read -p "> " SWAP_SIZE
		TARGET_VALID=$(fdisk -l /dev/$TARGET_DRIVE 2>&1 | grep -v 'cannot' | wc -l)
		if [ $TARGET_VALID == 0 ]
		then
			echo " Invalid disk: Type an id from the list above should look similar to 'sdX' or 'nvmeX'"
		fi
	done
fi

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

# 6. Ask about any specific architecture drivers / microcode (intel/amd microcode), (intel/amd (same) or nvidia gpu drivers) [SKIP: Should be done with Ansible script]

