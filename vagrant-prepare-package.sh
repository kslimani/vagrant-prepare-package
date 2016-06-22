#!/bin/bash

#
# Setup a custom Linux Debian VirtualBox VM for Vagrant.
#
# To run this script, log in from Virtualbox as root and type "init 1" to enter single user runlevel.
# This script cannot be run using SSH connection.
#

## SCRIPT VARIABLES

box_root_password="" # unused (todo: change root password if not empty)
box_vagrant_user="vagrant"
box_vagrant_group="vagrant"

required_packages="build-essential ca-certificates module-assistant sed sudo wget zerofree"
required_commands="apt-get awk cut fdisk grep locale-gen id"
color_error='\E[31;40m'
color_notice='\E[32;40m'
color_cmd='\E[35;40m'
color_none='\E[0m'
sudoers="${box_vagrant_user} ALL=(ALL) NOPASSWD: ALL"

_file_=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`

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
  CURRENT_RUN_LEVEL=$(runlevel|awk '{print $2}')
  if [ "$CURRENT_RUN_LEVEL" != "1" -a "$CURRENT_RUN_LEVEL" != "S" ]; then
    notice "Current runlevel is $CURRENT_RUN_LEVEL"
    notice "Log in from Virtualbox as root (NOT SSH !) and type ${color_cmd}init 1${color_notice} to enter single user runlevel"
    error "This script must be run in single user runlevel"
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
  export DEBIAN_FRONTEND=noninteractive
  notice "Updating APT packages ..."
  run_apt_get update
  run_apt_get upgrade
}

run_apt_get()
{
  run apt-get -q -y $*
}

setup_packages()
{
  for package in $required_packages
  do
    notice "Installing $package package ..."
    run_apt_get install $package
  done
}

setup_sshd()
{
  cfgfile=/etc/ssh/sshd_config
  cfgsearch=$(grep "^UseDNS no" $cfgfile)
  if [ -z "$cfgsearch" ]; then
    notice "Configuring OpenSSH SSH daemon ..."
    if ! printf "\nUseDNS no\n" >> $cfgfile; then
      error "Failed to configure OpenSSH SSH daemon"
    fi
  else
    notice "OpenSSH SSH daemon is already configured."
  fi
}

setup_locales()
{
  notice "Configuring locales ..."
  if [ ! -f "/etc/locale.gen.vpp" ]; then
    run cp /etc/locale.gen /etc/locale.gen.vpp
    printf "en_GB.UTF-8 UTF-8\nen_US.UTF-8 UTF-8\nfr_FR.UTF-8 UTF-8\n" > /etc/locale.gen
  fi
  if [ ! -f "/etc/default/locale.vpp" ]; then
    run cp /etc/default/locale /etc/default/locale.vpp
    printf "LANG=\"fr_FR.UTF-8\"\n" > /etc/default/locale
  fi
  run locale-gen
}

setup_user()
{
  if ! id $box_vagrant_user &>/dev/null; then
    notice "Adding $box_vagrant_user user"
    groupadd $box_vagrant_group
    run useradd -g $box_vagrant_group -s /bin/bash -d /home/$box_vagrant_user -m $box_vagrant_user
  else
    notice "$box_vagrant_user user already exists."
  fi
}

setup_sudo()
{
  if ! grep "$sudoers" /etc/sudoers &>/dev/null; then
    notice "Adding $box_vagrant_user user in sudoers file ..."
    if [ -f "/etc/sudoers.tmp" ]; then
      error "/etc/sudoers is locked by another visudo process."
    fi
    if ! run cp /etc/sudoers /etc/sudoers.tmp; then
      error "Failed to edit /etc/sudoers"
    fi
    run chmod 600 /etc/sudoers.tmp
    if ! rootsudoers=$(grep "^root\s\+ALL" /etc/sudoers.tmp); then
      run rm /etc/sudoers.tmp
      error "Failed to edit /etc/sudoers"
    fi
    if ! sed -i "s/$rootsudoers/$rootsudoers\n$sudoers/g" /etc/sudoers.tmp; then
      error "Failed to edit /etc/sudoers"
    fi
    if ! visudo -c -f /etc/sudoers.tmp &>/dev/null; then
      error "Failed to edit /etc/sudoers"
    fi
    run mv /etc/sudoers.tmp /etc/sudoers
    run chmod 440 /etc/sudoers
    run /etc/init.d/sudo restart
  else
    notice "$box_vagrant_user user is already in sudoers file"
  fi
}

setup_vagrant_key()
{
  notice "Downloading Vagrant keypair ..."
  keys_url=https://raw.github.com/mitchellh/vagrant/master/keys/
  run mkdir -p /home/$box_vagrant_user/.ssh
  run chmod 700 /home/$box_vagrant_user/.ssh
  run touch /home/$box_vagrant_user/.ssh/authorized_keys
  run wget ${keys_url}vagrant -O /home/$box_vagrant_user/.ssh/id_rsa
  run wget ${keys_url}vagrant.pub -O /home/$box_vagrant_user/.ssh/id_rsa.pub
  if ! grep "$(</home/$box_vagrant_user/.ssh/id_rsa.pub)" /home/$box_vagrant_user/.ssh/authorized_keys &>/dev/null; then
    notice "Adding Vagrant keypair ..."
    run cat /home/$box_vagrant_user/.ssh/id_rsa.pub >> /home/$box_vagrant_user/.ssh/authorized_keys
  else
    notice "Vagrant keypair already added."
  fi
  run chmod 600 /home/$box_vagrant_user/.ssh/*
  run chown -R $box_vagrant_user:$box_vagrant_group /home/$box_vagrant_user/.ssh
}

remove_libx11()
{
  notice "Remove X11 client libraries ..."
  run_apt_get purge libx11-6
  run_apt_get autoremove --purge
  run_apt_get clean
}

setup_vbox_ga()
{
  notice "Setup system for Virtualbox Guest Additions compilation ..."
  run_apt_get purge virtualbox-ose-guest-dkms virtualbox-ose-guest-x11 virtualbox-ose-guest-utils
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

setup_grub()
{
  if ! grep "^GRUB_TIMEOUT=1$" /etc/default/grub &>/dev/null; then
    notice "Updating GRUB ..."
    run sed -i -e 's/^GRUB_TIMEOUT=\([0-9]\)\+/GRUB_TIMEOUT=1/' /etc/default/grub;
    run update-grub
  else
    notice "GRUB is already configured."
  fi
}

shrink_box()
{
  notice "Removing unneeded localizations ..."
  run_apt_get install localepurge
  run localepurge
  run_apt_get purge localepurge
  notice "Clean APT packages ..."
  run_apt_get autoremove
  run_apt_get clean
  if [ "$opt_remove_doc" -eq "1" ]; then
    notice "Removing shared docs ..."
    run rm -rf /usr/share/doc/*
  fi
  if [ "$opt_remove_cache" -eq "1" ]; then
    notice "Removing cache ..."
    run rm -rf /var/cache/*
  fi
  notice "Removing temporary files ..."
  run rm -rf /tmp/*
}

setup_fs()
{
  fsname=$(fdisk -l|grep '*'|grep 'Linux'|cut -d ' ' -f 1) # experimental way to get file-systems name.
  notice "Remount $fsname in read only ..."
  run mount -o remount,ro $fsname
  notice "Performing zero free blocks on $fsname file-systems ..."
  notice "This may take a few minutes ..."
  run zerofree $fsname
  notice "Remount $fsname in read-write ..."
  run mount -o remount,rw $fsname
}

self_delete()
{
  if [ -f "$_file_" ]; then
    run rm $_file_
  fi
}


## MAIN SCRIPT

opt_delete=0
opt_remove_x11=0
opt_remove_doc=0
opt_remove_cache=0
opt_setup_locale=0
for var in "$@"
do
  case "$var" in
    --delete)
      opt_delete=1
    ;;
    --remove-doc)
      opt_remove_doc=1
    ;;
    --remove-cache)
      opt_remove_cache=1
    ;;
    --remove-x11)
      opt_remove_x11=1
    ;;
    --setup-locale)
      opt_setup_locale=1
    ;;
  esac
done

check_requirements
setup_apt
setup_packages
setup_sshd
if [ "$opt_setup_locale" -eq "1" ]; then
  setup_locales
fi
setup_user
setup_sudo
setup_vagrant_key
if [ "$opt_remove_x11" -eq "1" ]; then
  remove_libx11
fi
setup_vbox_ga
setup_grub
shrink_box
setup_fs
if [ "$opt_delete" -eq "1" ]; then
  self_delete
  notice "Box is ready to be packaged, this script has been self deleted"
else
  notice "Box is ready to be packaged, this script can be safely deleted"
fi
notice "Type ${color_cmd}shutdown -h now${color_notice} to turn off the box"
notice "Type ${color_cmd}vagrant package --base VBOXNAME${color_notice} from Host OS to create package.box file"
notice "For more details see http://docs.vagrantup.com/v2/cli/package.html"
exit 0
