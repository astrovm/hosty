hosty
=====

Ad blocker script for all Unix and Unix-like operating systems (Linux, GNU, BSD, Mac OS X, FreeBSD, OpenBSD).

![Comparison of total memory usage](https://i.imgur.com/qRVKMOQ.png)

## Manual instalation

### Requires
* sudo
* Wget
* cURL
* Gawk
* Gsed
* 7z
* zcat

#### How to install the requirements

* **Ubuntu/Mint/Debian:**  
$ sudo apt-get install wget curl gawk p7zip

* **Arch/Manjaro/Antergos:**  
$ sudo pacman -S wget curl gawk p7zip

* **Fedora/RHEL/CentOS:**  
$ sudo dnf install wget curl gawk p7zip

* **SUSE:**  
$ sudo zypper in wget curl gawk p7zip

* **Mac OS X:**  
First install Homebrew if you didn't before:  
$ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"  
Once installed:  
$ brew install coreutils gnu-sed wget curl gawk p7zip

### How to install hosty

$ curl -L git.io/hosty | sh

## How to run hosty

$ sudo hosty

## Whitelist

You can include exceptions editing the file `/etc/hosts.whitelist` (With root permissions) or `~/.hosty.whitelist`, one domain name per line.

Besides, hosty apply a internal whitelist for safety. If you want only use your custom whitelist and avoid the internal whitelist run:

$ sudo hosty --all

## Blacklist

You can add domains to block editing the file `/etc/hosts.blacklist` (With root permissions) or `~/.hosty.blacklist`, one domain name per line.

## Add host files sources

If you want to feed hosty with additional sources you just have to create a text file in `~/.hosty` and write in it one url per line.

$ echo "http://15hack.tomalaplaza.net/files/aede.txt" > ~/.hosty  
$ echo "http://datasaver.orgfree.com/hosts.zip" >> ~/.hosty

## How to restore your original hosts file

$ sudo hosty --restore

## How to see the result without changing the file

$ hosty --debug

## How to uninstall hosty

$ sudo rm /usr/local/bin/hosty
