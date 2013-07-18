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

required_packages="build-essential module-assistant sed sudo wget zerofree"
required_commands="apt-get cut fdisk grep locale-gen id"
color_error='\E[31;40m'
color_notice='\E[32;40m'
color_cmd='\E[35;40m'
color_none='\E[0m'
sudoers="${box_vagrant_user} ALL=(ALL) NOPASSWD: ALL"


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
  if [ "$(runlevel|cut -d ' ' -f 2)" != "1" ]; then
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
  notice "Updating APT packages ..."
  run apt-get -y update
  run apt-get -y upgrade
}

setup_packages()
{
  for package in $required_packages
  do
    notice "Installing $package package ..."
    run apt-get -y install $package
  done
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

setup_key()
{
  notice "Downloading Vagrant keypair ..."
  run wget https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub -O /tmp/vagrant.pub
  run mkdir -p /home/$box_vagrant_user/.ssh
  run touch /home/$box_vagrant_user/.ssh/authorized_keys
  if ! grep "$(</tmp/vagrant.pub)" /home/$box_vagrant_user/.ssh/authorized_keys &>/dev/null; then
    notice "Adding Vagrant keypair ..."
    run cat /tmp/vagrant.pub >> /home/$box_vagrant_user/.ssh/authorized_keys
    run chown -R $box_vagrant_user:$box_vagrant_group /home/$box_vagrant_user/.ssh
    run chmod 700 /home/$box_vagrant_user/.ssh
    run chmod 600 /home/$box_vagrant_user/.ssh/authorized_keys
  else
    notice "Vagrant keypair already added."
  fi
  run rm /tmp/vagrant.pub
}

setup_vbox_ga()
{
  notice "Setup system for Virtualbox Guest Additions compilation ..."
  run apt-get -y purge virtualbox-ose-guest-dkms virtualbox-ose-guest-x11 virtualbox-ose-guest-utils
  run m-a prepare
  tmp_iso=/tmp/iso
  mnt_iso=$tmp_iso/mnt
  run mkdir -p $mnt_iso
  run cd $tmp_iso
  notice "Getting Virtualbox LATEST.TXT ..."
  run wget http://download.virtualbox.org/virtualbox/LATEST.TXT -O LATEST.TXT
  vbox_version=$(<LATEST.TXT)
  notice "Downloading Virtualbox Guest Additions version $vbox_version ..."
  run wget http://download.virtualbox.org/virtualbox/${vbox_version}/VBoxGuestAdditions_${vbox_version}.iso -O VBoxGuestAdditions_${vbox_version}.iso
  run mount -o loop VBoxGuestAdditions_${vbox_version}.iso $mnt_iso
  notice "Installing Virtualbox Guest Additions version $vbox_version ..."
  sh $mnt_iso/VBoxLinuxAdditions.run # may fail on X11, safe to ignore.
  run umount $mnt_iso
  run cd
  run rm -rf $tmp_iso
  notice "Checking Virtualbox Guest Additions status"
  run /etc/init.d/vboxadd status
}

setup_grub()
{
  if ! grep "^GRUB_TIMEOUT=0$" /etc/default/grub &>/dev/null; then
    notice "Updating GRUB ..."
    run sed -i -e 's/^GRUB_TIMEOUT=\([0-9]\)\+/GRUB_TIMEOUT=0/' /etc/default/grub;
    run update-grub
  else
    notice "GRUB is already configured."
  fi
}

shrink_box()
{
  notice "Removing shared docs ..."
  run rm -rf /usr/share/doc
  notice "Removing Virtualbox Guest Additions sources ..."
  run rm -rf /usr/src/vboxguest*
  run rm -rf /usr/src/virtualbox-ose-guest*
  notice "Removing Linux headers ..."
  run rm -rf /usr/src/linux-headers*
  notice "Removing cache ..."
  run find /var/cache -type f -exec rm -rf {} \;
  notice "Removing locales (except fr_FR, en_US) ..."
  run rm -rf /usr/share/locale/{af,am,ar,as,ast,az,bal,be,bg,bn,bn_IN,br,bs,byn,ca,cr,cs,csb,cy,da,de,de_AT,dz,el,en_AU,en_CA,eo,es,et,et_EE,eu,fa,fi,fo,fur,ga,gez,gl,gu,haw,he,hi,hr,hu,hy,id,is,it,ja,ka,kk,km,kn,ko,kok,ku,ky,lg,lt,lv,mg,mi,mk,ml,mn,mr,ms,mt,nb,ne,nl,nn,no,nso,oc,or,pa,pl,ps,pt,pt_BR,qu,ro,ru,rw,si,sk,sl,so,sq,sr,sr*latin,sv,sw,ta,te,th,ti,tig,tk,tl,tr,tt,ur,urd,ve,vi,wa,wal,wo,xh,zh,zh_HK,zh_CN,zh_TW,zu}
  notice "Clean APT packages ..."
  run apt-get -y autoremove
  run apt-get -y clean
}

setup_locales()
{
  notice "Configuring locales ..."
  if [ ! -f "/etc/locale.gen.vpp" ]; then
    run cp /etc/locale.gen /etc/locale.gen.vpp
    printf "en_US.UTF-8 UTF-8\nfr_FR.UTF-8 UTF-8\n" > /etc/locale.gen
  fi
  if [ ! -f "/etc/default/locale.vpp" ]; then
    run cp /etc/default/locale /etc/default/locale.vpp
    printf "LANG=\"fr_FR.UTF-8\"\n" > /etc/default/locale
  fi
  run locale-gen
}

setup_fs()
{
  fsname=$(fdisk -l|grep '*'|grep 'Linux'|cut -d ' ' -f 1) # experimental way to get file-systems name.
  notice "Remount $fsname in read only ..."
  run mount -o remount,ro $fsname
  notice "Performing zero free blocks on $fsname file-systems ..."
  notice "This may take a few minutes ..."
  run zerofree $fsname
}


## MAIN SCRIPT

check_requirements
setup_apt
setup_packages
setup_user
setup_sudo
setup_key
setup_vbox_ga
setup_grub
shrink_box
setup_locales
setup_fs
notice "Box is ready to packaged"
notice "Type ${color_cmd}shutdown -h now${color_notice} to turn off the box"
notice "Type ${color_cmd}vagrant package --base VBOXNAME${color_notice} from Host OS to create package.box file"
notice "For more details see http://docs.vagrantup.com/v2/cli/package.html"
exit 0
