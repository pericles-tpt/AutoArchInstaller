
#!/bin/sh

# PURPOSE: A 1 file, POSIX-compliant, installation script for Arch Linux
#
# LABELS:
# CONSTANTS - Used to reduce inline logic and for validation
#             NOTE: In most cases you SHOULDN'T modify these
# CONFIG	- Modify these variables before running the script to configure
#			  your system
# MAIN      - Most of the logic is inlined here, i.e: instruction output,
# 		      user input, etc
# FUNCTIONS - More specialised behaviour that's called from MAIN

# CONSTANTS
MiB=$((1024*1024))
GiB=$(($MiB*1024))
PARTED_SECTOR_ALIGN=2048
BOOT_SIZE_B=$((1 * $GiB))
TMP_EFI_DIR="/mnt/tmp_efi"
ZRAM_PC_LIMIT="2"
ZRAM_COMPRESSION_RATIO=2 # This is a conservative estimate, it's often higher

## CONFIG
WIFI_SSID="Telemachou"	# Specify a WiFi SSID to configure WiFi
WIFI_SAVE_CONFIG=1  # Save the wifi configuration to auto-connect on boot

LVM_PART_FMT="ext4" # NOTE: LVM will take up the rest of the disk not used by BOOT_SIZE_B
ROOT_SIZE_B=$((32 * $GiB))  #
SWAP_SIZE_B=$((4 * $GiB))   # 0 => no swap (file)
HOME_SIZE_B=$((80 * $GiB))  # 0 => no home partition

ZRAM_PC="1"         # "" => no ZRAM, use a fraction string to enable and set the amount of ZRAM to
					#		use as a fraction of total system RAM (can exceed 1)
					#		NOTE: The specified amount is the max UNCOMPRESSED size, the amount of 
					# 			  physical memory used will likely be AT LEAST 1/2 this amount

HIBERNATE=1         # 1 => when enabled overrides SWAP_SIZE (if lt calculation) to:
					#	   ZRAM_PHYS_SIZE_B=$(((ZRAM_PC * RAM_SIZE_B) / ZRAM_COMPRESSION_RATIO)
					# 	   = (RAM_SIZE_B - ZRAM_PHYS_SIZE) + (2 * ZRAM_PHYS_SIZE)

ENCRYPT=1           # 1 => encrypt everything except for /boot

					# Pick one from here: https://images.linuxcontainers.org/
FEDORA_ROOTFS_URL = "https://images.linuxcontainers.org/images/fedora/40/amd64/default/20250826_20:33/rootfs.tar.xz"

INSTALL_PKG_LIST="base linux linux-firmware"
LOCALE="en_AU.UTF-8 UTF-8"

CONFIG_UPDATED=1    # TODO: Change this to 1 to acknowledge that you've updated the config

## FUNCTIONS
FN_INT_TO_YN(){
	if [ $1 -eq 1 ]
	then
		echo "YES"
	else
		echo "NO"
	fi
}
FN_VALIDATE_CFG(){
	if [ $CONFIG_UPDATED -eq 0 ]
	then
		echo "! config hasn't been modified, fill out the properties in the '## CONFIG' section of the script, exiting..."
		exit
	fi
}
FN_PRINT_CFG(){
	echo "Configuration:"
	CONFIGURE_WIFI="NO"
	if [ $WIFI_SSID != "" ]
	then
		CONFIGURE_WIFI="YES"
	fi
	echo "CONFIGURE_WIFI: $CONFIGURE_WIFI"
	if [ $WIFI_SSID != "" ]
	then
		echo "WIFI_SSID: $WIFI_SSID"
		b=$(FN_INT_TO_YN $WIFI_SAVE_CONFIG)
		echo "WIFI_SAVE_CONFIG: $b"
	fi
	echo ""

	echo "ROOT_SIZE_B: $ROOT_SIZE_B"
	if [ $HOME_SIZE_B -gt 0 ]
	then
		echo "SEPARATE HOME PARTITION: YES"
		echo "HOME_SIZE_B: $HOME_SIZE_B"
	fi
	if [ $SWAP_SIZE_B -gt 0 ]
	then
		echo "HAS SWAP: YES"
		echo "SWAP_SIZE_B: $SWAP_SIZE_B"
	fi
}
FN_PROMPT_YN(){
	read -p "> " PROMPT_RES
	if [ "$PROMPT_RES" = "Y" ] | [ "$PROMPT_RES" = "y" ] | [ "$PROMPT_RES" = "" ]
	then
		echo 1
	else
		echo 0
	fi
}
FN_TEST_WIFI(){
	ifaces=$(ip addr | grep ': <' | sed 's/://' | awk '{print $2}' | tr -d ':')

	fail_iface=0
	total_iface=0
	WIFI_FOUND_IFACE=""

	if [ "$WIFI_SSID" = "" ] || [ "$WIFI_PASS" = "" ]
	then
		echo "WARNING: WiFi credentials not set, if you wish to setup wifi, restart this script"
	else
		for i in $ifaces; do
			total_iface=$((total_iface+1))
			con_resp=$(iwctl --passphrase=$WIFI_PASS station $i connect $WIFI_SSID | grep 'not found\|Operation failed\|Argument format is invalid\|Invalid network name')
			if [ "$con_resp" != "" ]
			then
				a="not found"
				b="Invalid network name"
				if [ -z "${con_resp##*$a*}" ]
				then
					blah=1
					# echo "FAILED: Network device not found for $i" 
				elif [ -z "${con_resp##$b*}" ];
				then
					echo "FAILED: SID not found on $i"
				else
					echo "FAILED: Password is invalid on $i"
				fi
				fail_iface=$((fail_iface+1))
			else
				# echo "SUCCESS: Connected to interface $i"
				WIFI_FOUND_IFACE="$i"
				break
			fi
		done

		# Check how many of the network interfaces failed
		if [ $fail_iface -lt $total_iface ]
		then
			success_iface=$((total_iface-fail_iface))
			echo ""
			echo "Found a valid wifi interface: $WIFI_FOUND_IFACE"
			sleep_sec=3
			ping_count=5
			echo "Testing wifi connection, this will take a few seconds..."
			sleep $sleep_sec
			pingOutput=$(ping -c $ping_count google.com 2>&1)
			ping_has_err=$(echo "$pingOutput" | wc -l)
			if [ "$ping_has_err" = "1" ]
			then
				echo "WARNING: Connected to $WIFI_FOUND_IFACE BUT not connected to the internet"					
			else
				pingSuccessCount=$(echo "$pingOutput" | grep transmitted | awk '{print int($1)}')
				if [ $pingSuccessCount -gt 0 ]; then
					echo "SUCCESS: Connected to the internet!"
				else
					echo "WARNING: Connected to $WIFI_FOUND_IFACE BUT not connected to the internet"
				fi
			fi
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
}
FN_LIST_DISKS(){
	echo "$(printf "%-8s\t%4s\t%8s\t%5s\t%s\n" "ID" "TYPE" "CAPACITY" "%USED" "MODEL")"
	lsblk | grep disk | while read j; do	
		id=$(echo $j | awk '{print $1}')
		size=$(echo $j | awk '{print $4}')

		if [ $size = "0B" ]; then
			continue
		fi
		totalSizeBytes=$(fdisk -l "/dev/$id" | head -n 1 | awk '{print int($5)}')
		freeBytes=$(sfdisk --list-free "/dev/$id" | head -n 1 | awk '{print int($6)}')
		usedBytes=$((totalSizeBytes - freeBytes))
		capacityUsedPc="?"
		if [ $usedBytes -ge 0 ]; then
			capacityUsedPc=$(echo "scale=3; (($usedBytes/$totalSizeBytes) * 100)" | bc | awk '{printf "%.1f", $1}')
		fi

		maybe_model=""
		if [ -e "/sys/class/block/$id/device/model" ]; then
			maybe_model=$(cat /sys/class/block/"$id"/device/model | tr -d ' ')
		fi
		model="?"
		if [ "$maybe_model" != "" ]; then
			model="$maybe_model"
		fi
		type="?"
		if [ $(find /dev/disk/by-id/ -lname "*""$id" | grep usb | wc -l) -gt 0 ]; then 
			type="USB"
		else
			case "$id" in
				"sda"*)
					type="SATA";;
				"mmc"*)
					type="SD";;
				"nvme"*)
					type="NVME";;
				*)
					;;
			esac							
		fi
		echo "$(printf "%-8s\t%-4s\t%8s\t%5s\t%s\n" "$id" "$type" "$size" "$capacityUsedPc" "$model")"
	done 
}
FN_GET_EFI_PART(){
	MAYBE_EFI_LINE=$(fdisk -l "/dev/$TARGET_DISK" | grep EFI)
	if [ "$MAYBE_EFI_LINE" = "" ]
	then
		return
	fi

	MAYBE_EFI_PART=$(echo "$MAYBE_EFI_LINE" | awk '{print $1}')

	echo "a"

	# Make sure it's the ESP: https://wiki.archlinux.org/title/EFI_system_partition#Check_for_an_existing_partition
	mkdir $TMP_EFI_DIR
	mount $MAYBE_EFI_PART $TMP_EFI_DIR
	IS_EFI=0
	if [ -d "$TMP_EFI_DIR/EFI" ]
	then
		IS_EFI=1
	fi
	umount $TMP_EFI_DIR
	rmdir $TMP_EFI_DIR
	if [ IS_EFI -eq 1 ]
	then
		echo "$MAYBE_EFI_PART"
	fi
	echo "g"
}
FN_LAST_TARGET_DISK_PART(){
	echo "$(lsblk -nlpo NAME,TYPE "/dev/$TARGET_DISK" | grep part | sort | tail -n 1 | awk '{print $1}')"
}
FN_VALIDATE_PART_SIZES_B(){
	FREE_SPACE_B=$(($TARGET_FREE_SPACE_B - $START - $BOOT_SIZE_B))
	PAD=$(($FREE_SPACE_B % ($PARTED_SECTOR_ALIGN * $PHYS_SECTOR_SIZE)))
	FREE_SPACE_B=$(($FREE_SPACE_B - $PAD))
	if [ $FREE_SPACE_B -lt 0 ]
	then
		echo 0
	fi

	if [ $(($ROOT_SIZE_B + $HOME_SIZE_B + $SWAP_SIZE_B)) -gt $FREE_SPACE_B ] then
		echo 0
	fi
	echo 1
}
FN_ALIGN_END(){
	PAD=$(( $END % ($PARTED_SECTOR_ALIGN * $PHYS_SECTOR_SIZE) ))
	END=$(($END + $PAD))
}
FN_ALIGN_START(){
	PAD=$(( $START % ($PARTED_SECTOR_ALIGN * $PHYS_SECTOR_SIZE) ))
	START=$(($START + $PAD))
}

## MAIN
echo "## Started automated Arch Linux installer ##
"

# 0. Check config has been updated
FN_VALIDATE_CFG
FN_PRINT_CFG
echo "Are you happy with the configured settings above? [Y/n]"
CONFIG_OK_RESP=$(FN_PROMPT_YN)
if [ $CONFIG_OK_RESP -eq 0 ]
then
	echo "Please modify the '## CONFIG' section and re-run the script, exiting..."
	exit
fi

# 1. Setup WiFi
WIFI_FILE_NAME=""
WIFI_FILE_CONTENTS=""
echo ""
echo "STEP 1:  Setup Wifi"
if [ "$WIFI_SSID" != "" ]
then
	echo "Please provide your WIFI password below:"
	while [ "$WIFI_PASS" = "" ]; do
		read -s -p "> " WIFI_PASS
		if [ "$WIFI_PASS" = "" ]
		then
			echo "! No value provided for wifi password, please specify:"
		fi
	done
	echo ""

	FN_TEST_WIFI

	if [ $WIFI_SAVE_CONFIG -eq 1 ]
	then
		WIFI_FILE_NAME="${WIFI_SSID}.psk"
		WIFI_FILE_CONTENTS=$(printf "[Security]\nPassphrase=%s\n\n[Settings]\nAutoConnect=true" "$WIFI_PASS")
	fi
else
	echo "Wifi not configured, skipping wifi setup..."
fi
echo ""

# 2. Get the target drive
echo "STEP 2: Select the target drive for installation"
if [ "$TARGET_DISK" = "" ]
then
	echo "Which disk would you like to install to? Provide the 'ID' of the target:"

	LIST_DISKS_OUT=$(FN_LIST_DISKS)
	echo "$LIST_DISKS_OUT"

	VALID_DISKS_LIST=$(echo "$LIST_DISKS_OUT" | tail -n +2 | awk '{print $1}')

	TARGET_VALID=0
	while [ $TARGET_VALID -eq 0 ]; do
		read -p "> " TARGET_DISK
		TARGET_VALID=$(echo "$VALID_DISKS_LIST" | grep "^${TARGET_DISK}$" | wc -l)
		if [ $TARGET_VALID -gt 0 ]
		then
			break
		fi
		echo "! invalid disk: Type an id from the list above should look similar to 'sdX', 'nvmeX', etc"
	done
fi

# 3. Prompt user for them to decide whether to wipe the disk or not
WIPE_TARGET=0
echo "Would you like to wipe '$TARGET_DISK'? Will use remaining capacity otherwise [Y/n]"
WIPE_TARGET=$(FN_PROMPT_YN)

TARGET_FREE_SPACE_B=$(fdisk -l "/dev/$TARGET_DISK" | head -n 1 | awk '{print int($5)}')
START=0
TARGET_FREE_SECTORS_OUT=$(sfdisk --list-free "/dev/$TARGET_DISK")
PHYS_SECTOR_SIZE=$(echo "$TARGET_FREE_SECTORS_OUT" | grep 'Sector size' | awk '{print int($7)}')
SECTOR_ALIGN_SIZE_B=$(($PHYS_SECTOR_SIZE * $PARTED_SECTOR_ALIGN))
if [ $WIPE_TARGET -eq 0 ]; then
	# Iterate over free segments on disk, find the largest one to set as `TARGET_FREE_SPACE_B`
	TARGET_FREE_SECTOR_ENTS=$(echo "$TARGET_FREE_SECTORS_OUT" | tail -n +6)
	TARGET_FREE_SPACE_B=0
	echo "$TARGET_FREE_SECTOR_ENTS" | while IFS= read -r line; do
		CURR_START=$(echo "$line" | awk '{print int($1)}')
		CURR_FREE_SPACE_B=$(echo "$line" | awk -v var="$PHYS_SECTOR_SIZE" '{ result = int($3 * var); print result }')
		if [ $CURR_FREE_SPACE_B -gt $TARGET_FREE_SPACE_B ]
		then
			START=$CURR_START
			TARGET_FREE_SPACE_B=$CURR_FREE_SPACE_B
		fi
	done
fi
OFFSET=0
if [ $START -eq 0 ]; then
	OFFSET=$SECTOR_ALIGN_SIZE_B
	START=$(($OFFSET))
fi
FN_VALIDATE_PART_SIZES_B

# 4. Setup partition scheme (GPT) and create boot partition
parted "/dev/$TARGET_DISK" mklabel gpt
MAYBE_EXISTING_EFI=$(FN_GET_EFI_PART)
EFI_PART=$MAYBE_EXISTING_EFI
if [ "$EFI_PART" = "" ]
then
	END=$(($START+$BOOT_SIZE_B))
	FN_ALIGN_END
	parted "/dev/$TARGET_DISK" mkpart primary fat32 "${START}B" "${END}B"
	mkfs.vfat -F 32 /dev/sda1
	EFI_PART=$(FN_LAST_TARGET_DISK_PART)
	START=$(($END + $SECTOR_ALIGN_SIZE_B))
	FN_ALIGN_START
fi

END=$(($START + $LVM_PART_SIZE_B))
FN_ALIGN_END
parted "/dev/$TARGET_DISK" mkpart primary "$LVM_PART_FMT" "${START}B" "${END}B"
MAIN_PART=$(FN_LAST_TARGET_DISK_PART)
START=$((END + SECTOR_ALIGN_SIZE_B))
FN_ALIGN_START

# 4. If using encryption, set up encrypted partition here
ENCRYPT_MOUNT_POINT=""
if [ $ENCRYPT -eq 1 ]
then	
	echo "ENCRYPTION: Creating encrypted partition on $MAIN_PART"
	cryptsetup luksFormat $MAIN_PART
	echo "ENCRYPTION: Re-enter your password to open the encrypted partition"
	cryptsetup open $MAIN_PART cryptlvm
	ENCRYPT_MOUNT_POINT="/dev/mapper/cryptlvm"
fi

# SWAP (4GiB by default, (RAM - ZRAM) + (2 * ZRAM) for hibernate)
if [ $HIBERNATE -eq 1 ] then
	# TODO: Ensure this is applied to the installed system
	OLD_SWAP_SIZE_B=$SWAP_SIZE_B
	MIN_SWAP_SIZE_B=$(((TOTAL_MEMORY_B - ZRAM_B) + (2 * ZRAM_B)))
	if [ $SWAP_SIZE_B -lt $MIN_SWAP_SIZE_B ] then
		SWAP_SIZE_B=$MIN_SWAP_SIZE_B
	fi

	if [ $OLD_SWAP_SIZE_B -lt $SWAP_SIZE_B ] then
		NEW_SWAP_DIFF=$(($SWAP_SIZE_B - $OLD_SWAP_SIZE_B))
		OLD_HOME_SIZE_B=$HOME_SIZE_B
		if [ $HOME_SIZE_B -gt 0 ] then
			$HOME_SIZE_B=$(($HOME_SIZE_B - ($NEW_SWAP_DIFF / 2)))
		fi
		OLD_ROOT_SIZE_B=$ROOT_SIZE_B
		$ROOT_SIZE_B=$(($ROOT_SIZE_B - ($NEW_SWAP_DIFF / 2)))
		if [ $HOME_SIZE_B -lt 0 ] | [ $ROOT_SIZE_B -lt 0 ] then
			echo "! tried to resize swap for hibernate, but HOME_SIZE_B or ROOT_SIZE_B is negative after resize"
			exit
		fi

		echo "WARNING: Resizing swap for hibernate, HOME_SIZE_B and ROOT_SIZE_B may have changed"
		echo "HOME_SIZE_B, before: $OLD_HOME_SIZE_B, after: $HOME_SIZE_B"
		echo "ROOT_SIZE_B, before: $OLD_ROOT_SIZE_B, after: $ROOT_SIZE_B"
		echo "Are you happy with the resize? [Y/n]"
		RESIZE_FOR_SWAP=$(FN_PROMPT_YN)
		if [ $RESIZE_FOR_SWAP -lt 0 ] then
			echo "! NOT happy with resize, update your config and retry, exiting..."
			exit
		fi
	fi
fi

# 5. Create LVM "volume groups" for user mount points
pvcreate $ENCRYPT_MOUNT_POINT
vgcreate vg0 $ENCRYPT_MOUNT_POINT
lvcreate -L $HOME_SIZE_B vg0 -n lv_home
lvcreate -L $(($ROOT_SIZE_B + $SWAP_SIZE_B)) vg0 -n lv_root
modprobe dm_÷mod
vgscan
vgchange -ay
mkfs.ext4 /dev/vg0/lv_home
mkfs.ext4 /dev/vg0/lv_root

mount /dev/vg0/lv_root /mnt
mount --mkdir /dev/vg0/lv_home /mnt/home
mkdir /mnt/etc
mount --mkdir $EFI_PART /mnt/boot

arch-chroot /mnt

sudo wget -c $FEDORA_ROOTFS_URL
sudo tar -xf rootfs.tar.xz

if [ $SWAP_SIZE_B -gt 0 ] then
	mkswap -U clear --size 4G --file /swapfile
	swapon /swapfile
	echo "/swapfile none swap defaults 0 0" >> /etc/fstab
fi

# Zram (half RAM by default)
TOTAL_MEMORY_B=$(cat /proc/meminfo | grep MemTotal | awk '{print int($2) * 1000}')
ZRAM_B=$(echo "scale=0; $TOTAL_MEMORY_B * $ZRAM_PC_LIMIT" | bc)
if [ $ZRAM_B -gt 0 ]; then
	sudo dnf install zram-generator
	INSTALL_PKG_LIST="$INSTALL_PACKAGE_LIST zram-generator"
	echo "[zram0]\nzram-size = min(ram * $ZRAM_PC_LIMIT, 4096)\ncompression-algorithm = zstd" > /etc/systemd/zram-generator.conf
fi

# Hibernate

# 3. Generate the `fstab` file

# 4. Install packages to installation target

# 5. arch-chroot into environment (could this be a problem?)

# 5a. Install packaged (could be done with pacstrap

# 5b. Start services

# 5c. Edit build flags in mkinitcpio

# 5d. Locale-gen
sed -i "'s/#$LOCALE/$LOCALE/g'" /etc/locale.gen
locale-gen
localectl set-locale LANG=$LOCALE

# 5e. Set root passwd

# 5f. Create users

# 5g. Install sudo and edit `visudo`

# 5h. Install grub and setup boot files

# 5i. Setup swap

# 6. Ask about any specific architecture drivers / microcode (intel/amd microcode), (intel/amd (same) or nvidia gpu drivers) [SKIP: Should be done with Ansible script]

# 7. Provide option to setup Ansible on new system
