# TODO
1. Setup an Arch linux environment for testing
    a. Live environment, figure out how to `wget` this zipped repo from GH
    b. Installed environment (VM), clone repo and develop in the VM
2. Complete the disk selection stage
3. Complete the partitioning stage
    a. use LVM?
    b. use Encryption?
    c. use WHOLE or REMAINING space
        i. IF REMAINING -> what %
    d. specify each NEW partition and mapping
        e.g. separate '/' and '/home' partition OR on the same partition
    e. Formatting for each partition
        i. Should some be enforced? (e.g. '/boot' as FAT)
4. Setup swap, how much?
5. Generate `fstab` file
6. Install minimal packages to installation target (for successful boot)
7. `arch-chroot` into environment (could this be a problem?)
    a. Start services
    b. Edit build flags in `mkinitcpio`
    c. `locale-gen`
    d. set root passwd
    e. create other users (Optional? Ansible?)
    f. install `sudo` and edit `visudo`
    g. install `grub` and setup boot files
