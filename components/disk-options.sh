#!/bin/sh

lsblk | grep disk | while read j; do	
    id=$(echo $j | awk '{print $1}')
    size=$(echo $j | awk '{print $4}')

    # Used
    diskInfo=$(fdisk -l /dev/"$id")
    totalSizeBytes=$(echo $diskInfo | head -n 1 | awk '{print $5}')
    usedSizeBytes=0
    capacityUsed=$(fdisk -l /dev/$id | grep "^/dev/$id[\d]*" | awk '{print $5}' | while read k; do
        partSizeBytes=0
        # Num is rounded to NEAREST integer
        num=$(echo $k | sed 's/.$//' | awk '{print int($1+0.5)}')
        
        if [ $(echo "${k: -1}") = "B" ];
        then
            partSizeBytes=$num
        elif [ $(echo "${k: -1}") = "K" ];
        then
            partSizeBytes=$((num*1024))
        elif [ $(echo "${k: -1}") = "M" ];
        then
            partSizeBytes=$((num*1024*1024))
        elif [ $(echo "${k: -1}") = "G" ];
        then
            partSizeBytes=$((num*1024*1024*1024))
        elif [ $(echo "${k: -1}") = "T" ];
        then
            partSizeBytes=$((num*1024*1024*1024*1024))
        elif [ $(echo "${k: -1}") = "P" ];
        then
            partSizeBytes=$((num*1024*1024*1024*1024*1024))
        else
            echo "Sorry we can't handle EXABYTES of storage..."
            exit 1
        fi
        usedSizeBytes=$((usedSizeBytes+partSizeBytes))
        pcFree=$(awk "BEGIN {print int((($usedSizeBytes/$totalSizeBytes)*100)+0.5)}")
        if [ $pcFree -gt 100 ];
        then
            pcFree=100
        fi
        echo $pcFree
    done | tail -n 1)
    model=$(cat /sys/class/block/"$id"/device/model | tr -d ' ')
    isUSB=$(find /dev/disk/by-id/ -lname "*""$id" | grep usb | wc -l)
    if [ $isUSB -gt 0 ];
    then 
        echo "* $id ($size, $capacityUsed% USED): $model (USB)"
    else
        echo "* $id ($size, $capacityUsed% USED): $model"
    fi
done 