hosty
=====

Ad blocker script for Linux.

## Requires
* cURL
* Wget

##### How to install the requirements:

* Ubuntu/Mint/Debian:
$ sudo apt-get install curl wget

* Arch/Manjaro/Antergos:
$ sudo pacman -S curl wget

* Fedora/RHEL/CentOS:
$ sudo yum install curl wget

* SUSE:
$ sudo zypper in curl wget

## How to install hosty
$ sudo rm /usr/local/bin/hosty ; sudo wget -c https://github.com/juankfree/hosty/raw/master/hosty -O /usr/local/bin/hosty ; sudo chmod +x /usr/local/bin/hosty

## How to run hosty
$ hosty

## How to restore your original hosts file
$ sudo cp /etc/hosts.original /etc/hosts

## How to uninstall hosty
$ sudo rm /usr/local/bin/hosty
