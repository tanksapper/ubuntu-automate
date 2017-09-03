## CyanLab Ubuntu Automation ##
###############################

#!/bin/bash
# File names and paths
TMP="$HOME"                 # Destination Path to store the final ISO. 
hostname="ubuntu"
currentuser="$( whoami)"

# Define spinner function for slower tasks.
# Courtesy of http://fitnr.com/showing-a-bash-spinner.html
spinner()
{
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Define download function
# Courtesy of http://fitnr.com/showing-file-download-progress-using-wget.html
download()
{
    local url=$1
    echo -n "    "
    wget --progress=dot $url 2>&1 | grep --line-buffered "%" | \
        sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
    echo -ne "\b\b\b\b"
    echo " DONE"
}

# Define function to check if program is installed
# Courtesy of https://gist.github.com/JamieMason/4761049
function program_is_installed {
    # set to 1 initially
    local return_=1
    # set to 0 if not found
    type $1 >/dev/null 2>&1 || { local return_=0; }
    # return value
    echo $return_
}

# print a pretty header
echo
echo " +---------------------------------------------------+"
echo " |            UNATTENDED UBUNTU ISO MAKER            |"
echo " +---------------------------------------------------+"
echo

# Check for root privileges
if [ $currentuser != "root" ]; then
    echo " This script must been run using Sudo or as a root user."
    exit 1
fi

# Check to ensure using Ubuntu 16.04

fgrep "16.04" /etc/os-release >/dev/null 2>&1

if [ $? -eq 0 ]; then
     ub1604="yes"
fi

# Get the latest versions of Ubuntu LTS
TMPHTML=$TMP/tmphtml
rm $TMPHTMP >/dev/null 2>&1
wget -O $TMPHTML 'http://releases.ubuntu.com/' >/dev/null 2>&1

PREC=$(fgrep Precise $TMPHTML | head -1 | awk '{print $3}')
TRUS=$(fgrep Trusty $TMPHTML | head -1 | awk '{print $3}')
XENN=$(fgrep Xenial $TMPHTML | head -1 | awk '{print $3}')



# ask whether to include vmware tools or not
while true; do
    echo " which ubuntu edition would you like to remaster:"
    echo
    echo "  [1] Ubuntu $PREC LTS Server amd64 - Precise Pangolin"
    echo "  [2] Ubuntu $TRUS LTS Server amd64 - Trusty Tahr"
    echo "  [3] Ubuntu $XENN LTS Server amd64 - Xenial Xerus"
    echo
    read -p " please enter your preference: [1|2|3]: " ubver
    case $ubver in
        [1]* )  download_file="ubuntu-$PREC-server-amd64.iso"           # filename of the iso to be downloaded
                download_location="http://releases.ubuntu.com/$PREC/"     # location of the file to be downloaded
                new_iso_name="ubuntu-$PREC-server-amd64-unattended.iso" # filename of the new iso file to be created
                break;;
        [2]* )  download_file="ubuntu-$TRUS-server-amd64.iso"             # filename of the iso to be downloaded
                download_location="http://releases.ubuntu.com/$TRUS/"     # location of the file to be downloaded
                new_iso_name="ubuntu-$TRUS-server-amd64-unattended.iso"   # filename of the new iso file to be created
                break;;
        [3]* )  download_file="ubuntu-$XENN-server-amd64.iso"
                download_location="http://releases.ubuntu.com/$XENN/"
                new_iso_name="ubuntu-$XENN-server-amd64-unattended.iso"
                break;;
        * ) echo " please answer [1], [2] or [3]";;
    esac
done

if [ -f /etc/timezone ]; then
  timezone=`cat /etc/timezone`
elif [ -h /etc/localtime]; then
  timezone=`readlink /etc/localtime | sed "s/\/usr\/share\/zoneinfo\///"`
else
  checksum=`md5sum /etc/localtime | cut -d' ' -f1`
  timezone=`find /usr/share/zoneinfo/ -type f -exec md5sum {} \; | grep "^$checksum" | sed "s/.*\/usr\/share\/zoneinfo\///" | head -n 1`
fi

# ask the user questions about his/her preferences
echo -e "\e[7mPlease enter your preferred Timezone: \e[0m"
read -p "> " -i "${timezone}" TIMEZONE
echo -e "\e[7mPlease enter your preferred Username: \e[0m"
read -p "> " -i "hammer" USERNAME
echo -e "\e[7mPlease enter your preferred Password: \e[0m"
read -p "> " -s  PASSWORD
printf "\n"
echo -e "\e[7mPlease confirm your preferred Password: \e[0m"
read -p "> " -s PASSWORD2
printf "\n"
while [ "${PASSWORD}" != "${PASSWORD2}" ];
do
 echo
 echo -e "\e[41mPasswords do not match, please try again!\e[0m"
 echo
 echo -e "\e[7mPlease specify an admin password for Grafana\e[0m"
 read -p "> " -s PASSWORD
 echo
 echo
 echo -e "\e[7mPlease re-enter the password\e[0m"
 read -p "> " -s PASSWORD2
 echo
done
echo -e "\e[7mMake ISO Bootable via USB? \e[0m"
read -p "> " -i "Yes" BOOTABLE

# check if the passwords match to prevent headaches
if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
    echo " your passwords do not match; please restart the script and try again"
    echo
    exit
fi

# download the ubunto iso. If it already exists, do not delete in the end.
cd $TMP
if [[ ! -f $TMP/$download_file ]]; then
    echo -n "\e[7mDownloading $download_file \e[0m"
    download "$download_location$download_file"
fi
if [[ ! -f $TMP/$download_file ]]; then
	echo "Error: Failed to download ISO: $download_location$download_file"
	echo "This file may have moved or may no longer exist."
	echo
	echo "You can download it manually and move it to $TMP/$download_file"
	echo "Then run this script again."
	exit 1
fi

# Download Ubuntu Seed File
seed_file="ubuntu.seed"
if [[ ! -f $TMP/$seed_file ]]; then
    echo -n "\e[7mDownloading $seed_file \e[0m"
    download "https://raw.githubusercontent.com/netson/ubuntu-unattended/master/$seed_file"
fi

# Install Required Packages
echo -ne "\e[36mInstalling Required Packages\e[0m"
if [ $(program_is_installed "mkpasswd") -eq 0 ] || [ $(program_is_installed "mkisofs") -eq 0 ]; then
    (apt-get -y update > /dev/null 2>&1) &
    spinner $!
    (apt-get -y install whois genisoimage > /dev/null 2>&1) &
    spinner $!
fi
if [[ $bootable == "Yes" ]] || [[ $bootable == "Yes" ]] || [[ $bootable == "y" ]]; then
    if [ $(program_is_installed "isohybrid") -eq 0 ]; then
      #16.04
      if [ $ub1604 == "yes" ]; then
        (apt-get -y install syslinux syslinux-utils > /dev/null 2>&1) &
        spinner $!
      else
        (apt-get -y install syslinux > /dev/null 2>&1) &
        spinner $!
      fi
    fi
fi


# Create working folders
echo -ne "\e[36mRemastering ISO File\e[0m"
mkdir -p $TMP
mkdir -p $TMP/iso_org
mkdir -p $TMP/iso_new

# Mount the image
if grep -qs $TMP/iso_org /proc/mounts ; then
    echo " Image is already mounted, continue"
else
    (mount -o loop $TMP/$download_file $TMP/iso_org > /dev/null 2>&1)
fi

# Copy the iso contents to the working directory
(cp -rT $TMP/iso_org $TMP/iso_new > /dev/null 2>&1) &
spinner $!

# Set the language for the installation menu
cd $TMP/iso_new
# Doesn't work for 16.04
echo en > $TMP/iso_new/isolinux/lang

# 16.04
# Taken from https://github.com/fries/prepare-ubuntu-unattended-install-iso/blob/master/make.sh
sed -i -r 's/timeout\s+[0-9]+/timeout 1/g' $TMP/iso_new/isolinux/isolinux.cfg


# Set late command

if [ $ub1604 == "yes" ]; then
   late_command="apt-install wget; in-target wget --no-check-certificate -O /home/$username/start.sh https://git.cyanlab.io/tylerhammer/ubuntu-automated-install/raw/master/start.sh ;\
     in-target chmod +x /home/$username/start.sh ;"
else 
   late_command="chroot /target wget -O /home/$username/start.sh https://git.cyanlab.io/tylerhammer/ubuntu-automated-install/raw/master/start.sh ;\
     chroot /target chmod +x /home/$username/start.sh ;"
fi



# Copy the ubuntu seed file to the iso
cp -rT $TMP/$seed_file $TMP/iso_new/preseed/$seed_file

# Include firstrun script
echo "
# setup firstrun script
d-i preseed/late_command                                    string      $late_command" >> $TMP/iso_new/preseed/$seed_file

# Generate the password hash
pwhash=$(echo $PASSWORD | mkpasswd -s -m sha-512)

# Update the seed file to reflect the users' choices
# The normal separator for sed is /, but both the password and the timezone may contain it
# so instead, I am using @
sed -i "s@{{username}}@$username@g" $TMP/iso_new/preseed/$seed_file
sed -i "s@{{pwhash}}@$pwhash@g" $TMP/iso_new/preseed/$seed_file
sed -i "s@{{hostname}}@$hostname@g" $TMP/iso_new/preseed/$seed_file
sed -i "s@{{timezone}}@$timezone@g" $TMP/iso_new/preseed/$seed_file

# Calculate checksum for seed file
seed_checksum=$(md5sum $TMP/iso_new/preseed/$seed_file)

# Add the autoinstall option to the menu
sed -i "/label install/ilabel autoinstall\n\
  menu label ^Autoinstall NETSON Ubuntu Server\n\
  kernel /install/vmlinuz\n\
  append file=/cdrom/preseed/ubuntu-server.seed initrd=/install/initrd.gz auto=true priority=high preseed/file=/cdrom/preseed/ubuntu.seed preseed/file/checksum=$seed_checksum --" $TMP/iso_new/isolinux/txt.cfg

echo -ne "\e[36mCreating Remastered ISO File\e[0m"
cd $TMP/iso_new
(mkisofs -D -r -V "NETSON_UBUNTU" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $TMP/$new_iso_name . > /dev/null 2>&1) &
spinner $!

# Make iso bootable (for dd'ing to  USB stick)
if [[ $bootable == "Yes" ]] || [[ $bootable == "yes" ]] || [[ $bootable == "y" ]]; then
    isohybrid $TMP/$new_iso_name
fi

# cleanup
umount $TMP/iso_org
rm -rf $TMP/iso_new
rm -rf $TMP/iso_org
rm -rf $tmphtml


# print info to user
echo " -----"
echo " finished remastering your ubuntu iso file"
echo " the new file is located at: $TMP/$new_iso_name"
echo " your username is: $USERNAME"
echo " your password is: $PASSWORD"
echo " your hostname is: $hostname"
echo " your timezone is: $timezone"
echo

# unset vars
unset USERNAME
unset PASSWORD
unset hostname
unset timezone
unset pwhash
unset download_file
unset download_location
unset new_iso_name
unset TMP
unset seed_file
