# Setup a custom Linux Debian VirtualBox VM for Vagrant

It is a simple Bash script that i use to prepare a VirtualBox VM with Linux Debian to be packaged with Vagrant.

## Vagrant box package prepare script

To run `vagrant-prepare-package.sh` script, log in from Virtualbox as root and type `init 1` to enter single user runlevel.

__This script cannot be run using SSH connection.__

### Actions performed

* update APT packages
* add new user and group (password-less, default is `vagrant`)
* configure new user in sudoers file (remove sudo password prompt)
* install Vagrant "insecure" public/private keypair
* install latest VirtualBox Guest Additions (out of date Debian packages are removed)
* configure GRUB to 1 second timeout (making VM boot faster)
* remove some useless files (see script source for more details)
* configure SSH daemon (disable DNS lookup)
* configure Locales using `fr_FR.UTF-8` as default
* mount boot file-system as read only & perform zero free blocks (making the disk more easily compressible)

If optional `--delete` argument is used, the script deletes itself at the end.

If optional `--remove-doc` argument is used, `/usr/share/doc` folder content is deleted.

If optional `--remove-cache` argument is used, `/var/cache` folder content is deleted.

If optional `--remove-x11` argument is used, `libx11-6` is removed before install VirtualBox Guest Additions.

## Virtualbox guest additions upgrade script

The `upgrade-vbox-ga.sh` script upgrade Virtualbox guest additions to latest version.

__This script must be run from VM as root user.__
