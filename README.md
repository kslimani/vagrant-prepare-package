Setup a custom Linux Debian VirtualBox VM for Vagrant
=====================================================

To run this script, log in from Virtualbox as root and type `init 1` to enter single user runlevel.

This script cannot be run using SSH connection.


Actions performed
-----------------

* update APT packages
* add new user and group (password-less, default is `vagrant`)
* configure new user in sudoers file (remove sudo password prompt)
* install Vagrant "insecure" public/private keypair
* install latest VirtualBox Guest Additions (out of date Debian packages are removed)
* configure GRUB to 1 second timeout (making VM boot faster)
* remove some useless files (see script source for more details)
* configure Locales fr_FR.UTF-8 & en_US.UTF-8 (default locale is `fr_FR.UTF-8`)
* mount boot file-system as read only & perform zero free blocks (making the disk more easily compressible)
