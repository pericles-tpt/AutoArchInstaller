# AutoArchInstaller

A project to completely automate the arch linux installation process from a live USB to a fully configured installation.

The goal of this project is to create a script that "front loads" all the user interaction for the process to achieve a *mostly* hands-free installation experience. In addition, if the user specifies it, an ansible script can be run to complete all of the post-installation steps and setup the rest of the user's environment.

**WARNING:** This script is INCOMPLETE, as such it's highly recommended NOT to use it yet, using this script in its current state may result in DATA LOSS. If you'd like to test the script it's highly recommended to test it on a computer/VM WITHOUT ACCESS TO ANY EXISTING DATA.

## Requirements
This script aims to be **POSIX compliant** and to **not require any additional dependencies** (in addition to the default arch live installer). 

## Installer Stages
1. Prompt the user for all the required environment variables, for a completely 'hands free' installation
  - Will only prompt for environment variables that aren't already set when the script starts
2. Run the installation scripts to get to a bootable arch linux environment
  - EXTRA: IF auto wifi setup fails, ask to search for WiFi drivers for hardware, lookup corresponding software, once found ask the user if they'd like to install it (indicate if it's non-free) then install.
3. IF a link is provided to an ansible `zip` file. Download, unzip and *attempt* to run it.

## TO DO

- [ ] Write logic to prompt user for all environment variable that are not found
- [X] Create entrypoint for installation script(s) (i.e. `main.sh`)
- [X] (OPTIONAL) Write automated WiFI installation
- [ ] Write disk formatting and partitioning logic
- [ ] Generate `fstab`
- [ ] Install packages to installation root
- [ ] `arch-chroot`
- [ ] Start services
- [ ] Edit `mkinitcpio.conf` build flags
- [ ] Set locale
- [ ] Set root password
- [ ] Create user account and set their password
  - [ ] Multiple user accounts?
- [ ] Install `sudo` and edit `visudo`
- [ ] Install grub and setup boot files
- [ ] Setup swap
- [ ] (OPTIONAL) Install/configure any remaining hardware specific packages/configuration
- [ ] (OPTIONAL) Write ansible download and run logic
  - [ ] Install dependencies for ansible
  - [ ] Download `zip` and unzip it
  - [ ] Run ansible playbook
- [ ] Reboot!
