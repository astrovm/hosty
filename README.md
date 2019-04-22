hosty
=====

Ad blocker script for Unix and Unix-like operating systems.

![Comparison of total memory usage](https://i.imgur.com/qRVKMOQ.png)

## Manual instalation

### Requires
* sudo
* wget
* curl
* gawk
* sed
* p7zip
* gzip

#### How to install the requirements

* **Ubuntu/Mint/Debian:**  
$ sudo apt install wget curl gawk sed p7zip gzip

* **Arch/Manjaro/Antergos:**  
$ sudo pacman -S wget curl gawk sed p7zip gzip

* **Fedora/RHEL/CentOS:**  
$ sudo dnf install wget curl gawk sed p7zip gzip

### How to install hosty

$ curl -L git.io/hosty | sh

## How to run hosty

$ sudo hosty

## Whitelist

You can include exceptions editing the file `/etc/hosts.whitelist` (with root permissions) or `~/.hosty.whitelist`, one domain name per line.

Besides, hosty apply a internal whitelist for safety. If you want only use your custom whitelist and avoid the internal whitelist run:

$ sudo hosty --all

## Blacklist

You can add domains to block editing the file `/etc/hosts.blacklist` (with root permissions) or `~/.hosty.blacklist`, one domain name per line.

## Add host files sources

If you want to feed hosty with additional sources you just have to create a text file in `/etc/hosty` (with root permissions) or `~/.hosty` and write in it one url per line.

## How to restore your original hosts file

$ sudo hosty --restore

## How to see the hosty version of your hosts file without modifying your system

$ hosty --debug

or

$ hosty --debug --all

## How to uninstall hosty

$ sudo rm /usr/local/bin/hosty
