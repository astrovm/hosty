hosty
=====

Ad blocker script for Linux.

![Comparison of total memory usage](http://chart.apis.google.com/chart?chs=450x150&cht=bhs&chtt=Comparison%20of%20total%20memory%20usage&chd=s:0489&chxl=0:|AdBlock%20(849.8%20MB)|Adblock%20Plus%20(838.7%20MB)|No%20ad%20blocker%20(775.3%20MB)|Hosty%20(725.6%20MB)|&chxt=y)

## AUR

#### If you have Arch Linux or Arch based distribution compatible with AUR (Manjaro, Antergos, ArchBang, Bridge Linux) then you can simply install hosty from the AUR:

##### $ yaourt -S hosty

https://aur.archlinux.org/packages/hosty

## Manual instalation

### Requires
* cURL
* Wget

#### How to install the requirements

* Ubuntu/Mint/Debian:
$ sudo apt-get install curl wget

* Arch/Manjaro/Antergos:
$ sudo pacman -S curl wget

* Fedora/RHEL/CentOS:
$ sudo yum install curl wget

* SUSE:
$ sudo zypper in curl wget

### How to install hosty
$ sudo rm /usr/local/bin/hosty ; sudo wget -c https://github.com/juankfree/hosty/raw/master/hosty -O /usr/local/bin/hosty ; sudo chmod +x /usr/local/bin/hosty

## How to run hosty
$ hosty

## Whitelist
You can include exceptions editing the file /etc/hosts.whitelist (With root permissions), one per line.

#### Valid examples:

* example.com (All lines containing this text will be removed.)

* www.example.com 

* 0.0.0.0 example.com 

* 127.0.0.1 www.example.com 

* example (If you just put a word also works but careful because any page might have that word.)

## How to restore your original hosts file
$ sudo cp /etc/hosts.original /etc/hosts

## How to uninstall hosty
$ sudo rm /usr/local/bin/hosty
