#!/bin/bash

#
# Install latest Virtualbox guest additions
#
# This script need to be run as root user.
#

## SCRIPT VARIABLES

required_packages="build-essential module-assistant sed sudo wget zerofree"
required_commands="apt-get awk cut fdisk grep locale-gen id"
color_error='\E[31;40m'
color_notice='\E[32;40m'
color_cmd='\E[35;40m'
color_none='\E[0m'


## SCRIPT FUNCTIONS

date_time()
{
  date +%Y-%m-%d" "%H:%M:%S
}

notice()
{
  printf "${color_notice}$(date_time) [NOTICE] $*${color_none}\n"
}

error()
{
  printf "${color_error}$(date_time) [ERROR] $*${color_none}\n"
  exit 1
}

run()
{
  if ! $*; then
    error "Failed to run: $*"
  fi
}

check_requirements()
{
  if [ "root" != "$USER" ]; then
    error "This script must be run as root user."
  fi
  for reqcmd in $required_commands
  do
    if ! which $reqcmd &>/dev/null; then
      error "Failed to find required command '$reqcmd'."
    fi
  done
}

setup_apt()
{
  notice "Updating APT packages ..."
  run apt-get -q -y update
  run apt-get -q -y upgrade
}

setup_packages()
{
  for package in $required_packages
  do
    notice "Installing $package package ..."
    run apt-get -q -y install $package
  done
}

setup_vbox_ga()
{
  notice "Setup system for Virtualbox Guest Additions compilation ..."
  run apt-get -q -y purge virtualbox-ose-guest-dkms virtualbox-ose-guest-x11 virtualbox-ose-guest-utils
  run m-a -i prepare
  tmp_iso=/tmp/iso
  mnt_iso=$tmp_iso/mnt
  run mkdir -p $mnt_iso
  run cd $tmp_iso
  notice "Getting Virtualbox LATEST.TXT ..."
  run wget http://download.virtualbox.org/virtualbox/LATEST.TXT -O LATEST.TXT
  vbox_version=$(<LATEST.TXT)
  vbox_current_version=$(modinfo vboxguest|grep "^version: "|awk '{print $2}')
  if [ "$vbox_current_version" != "$vbox_version" ]; then
    notice "Downloading Virtualbox Guest Additions version $vbox_version ..."
    run wget http://download.virtualbox.org/virtualbox/${vbox_version}/VBoxGuestAdditions_${vbox_version}.iso -O VBoxGuestAdditions_${vbox_version}.iso
    run mount -o loop VBoxGuestAdditions_${vbox_version}.iso $mnt_iso
    notice "Installing Virtualbox Guest Additions version $vbox_version ..."
    notice "Answer ${color_cmd}yes${color_notice} if requested by installation process."
    sh $mnt_iso/VBoxLinuxAdditions.run # may fail on X11, safe to ignore.
    run umount $mnt_iso
  else
    notice "Virtualbox Guest Additions already up-to-date. (version $vbox_current_version)."
  fi
  run cd
  run rm -rf $tmp_iso
  notice "Checking Virtualbox Guest Additions status"
  run /etc/init.d/vboxadd status
}


## MAIN SCRIPT

check_requirements
setup_apt
setup_packages
setup_vbox_ga

notice "Installation done."
exit 0
