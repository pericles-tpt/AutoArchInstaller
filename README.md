# AutoArchInstaller

A project to completely automate the arch linux installation process from a live USB to a fully configured installation.

## Requirements
This script aims to be **POSIX compliant** and to **not require any additional dependencies** (in addition to the default arch live installer). 

## Installer Stages
1. Prompt the user for all the required environment variables, for a completely 'hands free' installation
  - Will only prompt for environment variables that aren't already set when the script starts
2. Run the installation scripts to get to a bootable arch linux environment (including some hardware specific drivers e.g. intel, amd, nvidia, etc)
3. IF a link is provided to an ansible `zip` file. Download, unzip and *attempt* to run it.

## Goals

- [ ] Write logic to prompt user for all environment variable that are not found
- [X] Create entrypoint for installation script(s) (i.e. `main.sh`)
- [X] Write automated WiFI installation
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
- [ ] Install/configure any remaining hardware specific packages/configuration
- [ ] Write ansible download and run logic
  - [ ] Change to root directory of installation `arch-chroot`
  - [ ] Install dependencies for ansible
  - [ ] Download `zip` and unzip it
  - [ ] Run ansible playbook
