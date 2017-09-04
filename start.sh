#!/bin/bash

USER=${logname}

clear

# Checking for Root Permissions
check_your_privilege () {
    if [[ "$(id -u)" != 0 ]]; then
        echo -e "\e[91mError: This setup script requires root permissions. Please run the script as root.\e[0m" > /dev/stderr
        exit 1
    fi
}
check_your_privilege

# Ask questions to initialize VM
echo -e "\e[7mWhat is the hostname of this VM? \e[0m"
read -p "> " HOSTNAME

echo

echo -e "\e[7mWhat is the domain of this VM? \e[0m"
read -p "> " DOMAIN

echo

echo -e "\e[7mWhat is the IP you want to set for this VM? \e[0m"
read -p "> " STATICIP

echo

echo -e "\e[7mWhat is the netmask you want to set for this VM? \e[0m"
read -p "> " NETMASK

echo

echo -e "\e[7mWhat is the gateway you want to set for this VM? \e[0m"
read -p "> " GATEWAY

echo

echo -e "\e[7mWhat are the nameservers you want to set for this VM? (Seperate with a space)\e[0m"
read -p "> " NAMESERVERS

echo

echo -e "\e[7mPlease specify an new password for ${USERNAME}\e[0m"
read -p "> " -s NEWPW

echo
echo

echo -e "\e[7mPlease re-enter the password\e[0m"
read -p "> " -s NEWPW2

echo
echo

while [ "${NEWPW}" != "${NEWPW2}" ];
do
 echo
 echo -e "\e[41mPasswords do not match, please try again!\e[0m"
 echo
 echo -e "\e[7mPlease specify an new password for ${USERNAME}\e[0m"
 read -p "> " -s NEWPW
 echo
 echo
 echo -e "\e[7mPlease re-enter the password\e[0m"
 read -p "> " -s NEWPW2
 echo
done


# Adjust Hostname
echo -ne "\e[36mAdjusting Hostname\e[0m"
echo ${HOSTNAME} > /etc/hostname
echo -e "\r\033[K\e[36mAdjusting Hostname ----- Complete\e[0m"

# Adjust Hosts
echo -ne "\e[36mAdjusting Hosts\e[0m"
sed -i "2s/.*/127.0.1.1     ${HOSTNAME}.${DOMAIN}   ${HOSTNAME}/" /etc/hosts
echo -e "\r\033[K\e[36mAdjusting Hosts ----- Complete\e[0m"

# Set Static IP
echo -ne "\e[36mSetting Static IP\e[0m"
cat >"/etc/network/interfaces"<<EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto ens160
iface ens160 inet static
address ${STATICIP}
netmask ${NETMASK}
gateway ${GATEWAY}
dns-nameservers ${NAMESERVERS}
# This is an autoconfigured IPv6 interface
iface ens160 inet6 auto

EOF
echo -e "\r\033[K\e[36mSetting Static IP ----- Complete\e[0m"

# Update Password
echo -ne "\e[36mUpdating password for ${logname}\e[0m"
echo '${logname}:${NEWPW}' | chpasswd
echo -e "\r\033[K\e[36mUpdating password for ${logname} ----- Complete\e[0m"

# Download SSH Key
wget http://192.168.0.105/preseed/authorized_keys -O /home/${USER}/.ssh/authorized_keys >>/dev/null 

echo -ne "\e[36mUpdating System - This may take awhile!\e[0m"
sudo apt-get -y update >/dev/null && sudo apt-get -y upgrade >/dev/null 
echo -e "\r\033[K\e[36mUpdating System ----- Complete\e[0m"

# finish
echo -e "\e[36mSetup Complete. Rebooting\e[0m"

# reboot
reboot
