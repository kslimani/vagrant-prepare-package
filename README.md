# Setup a custom Linux Debian VirtualBox VM for Vagrant

It is a simple Bash script that i use to prepare a VirtualBox VM with Linux Debian to be packaged with Vagrant.

## Vagrant box package prepare script

### Usage

Log in from Virtualbox as root (NOT SSH !) and run "prepare" task.

Then enter single user runlevel and run "zerofree" task.

```shell
Usage: vagrant-prepare-package.sh [OPTIONS] <TASK>

TASKS :
   prepare    prepare the VM to be packaged with Vagrant
   zerofree   mount fs as read only and fills unallocated blocks with zeroes

OPTIONS :
   --delete         self-delete this script at end
   --remove-cache   delete /var/cache folder content
   --remove-doc     delete /usr/share/doc folder content
   --remove-x11     remove libx11-6 package before install VirtualBox Guest Additions
   --setup-locale   configure locale with fr_FR.UTF-8 as default language
```

### "prepare" task

* update APT packages
* add new user and group (password-less, default is `vagrant`)
* configure new user in sudoers file (remove sudo password prompt)
* install Vagrant "insecure" public/private keypair
* install latest VirtualBox Guest Additions (version can be lock with `VBOX_GA` env variable)
* configure GRUB to 1 second timeout (making VM boot faster)
* remove some useless files (see script source for more details)
* disable DNS lookup in SSH server configuration

### "zerofree" task

* mount boot file-system as read only & perform zero free blocks (making the disk more easily compressible)

## Virtualbox guest additions upgrade script

The `upgrade-vbox-ga.sh` script upgrade Virtualbox guest additions to latest version.

__This script must be run from VM as root user.__
