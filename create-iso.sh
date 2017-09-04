#!/bin/bash

#######################################
## CyanLab Ubuntu Install Automation ##
#######################################

# Checking for Root Permissions
check_your_privilege () {
    if [[ "$(id -u)" != 0 ]]; then
        echo -e "\e[91mError: This setup script requires root permissions. Please run the script as root.\e[0m" > /dev/stderr
        exit 1
    fi
}
check_your_privilege

clear

# File names & paths
TMP="$HOME"  # Destination folder to store the final iso file
HOSTNAME="ubuntu"
CURRENTUSER="$( whoami)"

# Define spinner function that displays during slow tasks.
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
download()
{
    local url=$1
    echo -n "    "
    wget --progress=dot $url 2>&1 | grep --line-buffered "%" | \
        sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
    echo -ne "\b\b\b\b"
    echo -e "\e[36m ----- Complete\e[0m"
}

# Define function to check if program is installed
function program_is_installed {
    # set to 1 initially
    local return_=1
    # set to 0 if not found
    type $1 >/dev/null 2>&1 || { local return_=0; }
    # return value
    echo $return_
}

# Begin Display
echo
echo "+-----------------------------------------------------------+"
echo "|            CYANLAB UNATTENDED UBUNTU ISO MAKER            |"
echo "+-----------------------------------------------------------+"
echo

# Check that 16.04 is being used

fgrep "16.04" /etc/os-release >/dev/null 2>&1

if [ $? -eq 0 ]; then
     ub1604="yes"
fi

# Get the latest versions of Ubuntu LTS

TMPHTML=${TMP}/TMPHTML
rm ${TMPHTML} >/dev/null 2>&1
wget -O ${TMPHTML} 'http://releases.ubuntu.com/' >/dev/null 2>&1

PREC=$(fgrep Precise ${TMPHTML} | head -1 | awk '{print $3}')
TRUS=$(fgrep Trusty ${TMPHTML} | head -1 | awk '{print $3}')
XENN=$(fgrep Xenial ${TMPHTML} | head -1 | awk '{print $3}')



# Download Ubuntus
while true; do
    echo -e "\e[7mWhich version of Ubuntu would you like to remaster?\e[0m"
    echo
    echo -e "\e[36m[1] Ubuntu ${PREC} LTS Server amd64 - Precise Pangolin\e[0m"
    echo -e "\e[36m[2] Ubuntu ${TRUS} LTS Server amd64 - Trusty Tahr\e[0m"
    echo -e "\e[36m[3] Ubuntu ${XENN} LTS Server amd64 - Xenial Xerus\e[0m"
    echo
    read -p "Please enter your preference: [1|2|3]: " UBVER
    case ${UBVER} in
        [1]* )  DOWNLOAD_FILE="ubuntu-${PREC}-server-amd64.iso"           # filename of the iso to be downloaded
                DOWNLOAD_LOCATION="http://releases.ubuntu.com/${PREC}/"     # location of the file to be downloaded
                NEW_ISO_NAME="ubuntu-${PREC}-server-amd64-unattended.iso" # filename of the new iso file to be created
                break;;
        [2]* )  DOWNLOAD_FILE="ubuntu-${TRUS}-server-amd64.iso"             # filename of the iso to be downloaded
                DOWNLOAD_LOCATION="http://releases.ubuntu.com/${TRUS}/"     # location of the file to be downloaded
                NEW_ISO_NAME="ubuntu-${TRUS}-server-amd64-unattended.iso"   # filename of the new iso file to be created
                break;;
        [3]* )  DOWNLOAD_FILE="ubuntu-${XENN}-server-amd64.iso"
                DOWNLOAD_LOCATION="http://releases.ubuntu.com/${XENN}/"
                NEW_ISO_NAME="ubuntu-${XENN}-server-amd64-unattended.iso"
                break;;
        * ) echo " Please answer [1], [2] or [3]";;
    esac
done

if [ -f /etc/timezone ]; then
  timezone=`cat /etc/timezone`
elif [ -h /etc/localtime]; then
  timezone=`readlink /etc/localtime | sed "s/\/usr\/share\/zoneinfo\///"`
else
  CHECKSUM=`md5sum /etc/localtime | cut -d' ' -f1`
  timezone=`find /usr/share/zoneinfo/ -type f -exec md5sum {} \; | grep "^${CHECKSUM}" | sed "s/.*\/usr\/share\/zoneinfo\///" | head -n 1`
fi

echo

# User Preferences
# User Preferences
echo -e "\e[7mPlease enter your preferred timezone: (Uses TZ Database Times (Example: America/New_York)) \e[0m"
read -p "> " TIMEZONE

echo

echo -e "\e[7mPlease enter your preferred username: \e[0m"
read -p "> " USERNAME

echo

echo -e "\e[7mPlease specify a password for ${USERNAME}: \e[0m"
read -p "> " -s PASSWORD

echo
echo

echo -e "\e[7mPlease re-enter the password\e[0m"
read -p "> " -s PASSWORD2

echo
echo

# Check if passwords match
while [ "${PASSWORD}" != "${PASSWORD2}" ];
do
 echo
 echo -e "\e[41mPasswords do not match, please try again!\e[0m"
 echo
 echo -e "\e[7mPlease specify a password for ${USERNAME}: \e[0m"
 read -p "> " -s PASSWORD
 echo
 echo
 echo -e "\e[7mPlease re-enter the password\e[0m"
 read -p "> " -s PASSWORD2
 echo
done

echo -e "\e[7mMake ISO bootable via USB? [y/n]\e[0m"
read -p "> " BOOTABLE

clear

# Download the Ubunto iso. If it already exists, do not delete in the end.
cd ${TMP}
if [[ ! -f ${TMP}/${DOWNLOAD_FILE} ]]; then
    echo -ne "\e[36mDownloading - ${DOWNLOAD_FILE}\e[0m"
    download "${DOWNLOAD_LOCATION}${DOWNLOAD_FILE}"
fi
if [[ ! -f ${TMP}/${DOWNLOAD_FILE} ]]; then
	echo -e "\e[91mError: Failed to download ISO: ${DOWNLOAD_LOCATION}${DOWNLOAD_FILE}\e[0m"
	echo -e "\e[91mThis file may have moved or may no longer exist.\e[0m"
	echo
	echo -e "\e[91mYou can download it manually and move it to ${TMP}/${DOWNLOAD_FILE}\e[0m"
	echo -e "\e[91mThen run this script again.\e[0m"
	exit 1
fi

# Download ubuntu seed file
SEED_FILE="ubuntu.seed"
if [[ ! -f ${TMP}/${SEED_FILE} ]]; then
    echo -ne "\e[36mDownloading - ${SEED_FILE}\e[0m"
    download "https://git.cyanlab.io/tylerhammer/ubuntu-automated-install/raw/master/ubuntu.seed"
fi

# Install required packages
echo -ne "\e[36mInstalling required packages\e[0m"
if [ $(program_is_installed "mkpasswd") -eq 0 ] || [ $(program_is_installed "mkisofs") -eq 0 ]; then
    (apt-get -y update > /dev/null 2>&1) &
    spinner $!
    (apt-get -y install whois genisoimage > /dev/null 2>&1) &
    spinner $!
fi
if [[ $BOOTABLE == "yes" ]] || [[ $BOOTABLE == "y" ]]; then
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
mkdir -p ${TMP}
mkdir -p ${TMP}/iso_org
mkdir -p ${TMP}/iso_new
echo -e "\r\033[K\e[36mInstalling required packages ----- Complete\e[0m"

echo -ne "\e[36mRemastering ISO\e[0m"
# Mount the image
if grep -qs ${TMP}/iso_org /proc/mounts ; then
    echo "Image is already mounted, continue"
else
    (mount -o loop ${TMP}/${DOWNLOAD_FILE} ${TMP}/iso_org > /dev/null 2>&1)
fi

# Copy the iso contents to the working directory
(cp -rT ${TMP}/iso_org ${TMP}/iso_new > /dev/null 2>&1) &
spinner $!

# Set the language for the installation menu
cd ${TMP}/iso_new
#doesn't work for 16.04
echo en > ${TMP}/iso_new/isolinux/lang

# 16.04
sed -i -r 's/timeout\s+[0-9]+/timeout 1/g' ${TMP}/iso_new/isolinux/isolinux.cfg

# Set late command

if [ $ub1604 == "yes" ]; then
   late_command="apt-install wget; in-target wget --no-check-certificate -O /home/${USERNAME}/start.sh https://git.cyanlab.io/tylerhammer/ubuntu-automated-install/raw/master/start.sh ;\
     in-target chmod +x /home/${USERNAME}/start.sh ;"
else 
   late_command="chroot /target wget -O /home/${USERNAME}/start.sh https://git.cyanlab.io/tylerhammer/ubuntu-automated-install/raw/master/start.sh ;\
     chroot /target chmod +x /home/${USERNAME}/start.sh ;"
fi

# Copy the ubuntu seed file to the iso
cp -rT ${TMP}/${SEED_FILE} ${TMP}/iso_new/preseed/${SEED_FILE}

# Include firstrun script
echo "
# setup firstrun script
d-i preseed/late_command                                    string      $late_command" >> ${TMP}/iso_new/preseed/${SEED_FILE}

# Generate the password hash
PWHASH=$(echo ${PASSWORD} | mkpasswd -s -m sha-512)

# Update the seed file to reflect the users' choices
sed -i "s@{{USERNAME}}@${USERNAME}@g" ${TMP}/iso_new/preseed/${SEED_FILE}
sed -i "s@{{PWHASH}}@${PWHASH}@g" ${TMP}/iso_new/preseed/${SEED_FILE}
sed -i "s@{{HOSTNAME}}@${HOSTNAME}@g" ${TMP}/iso_new/preseed/${SEED_FILE}
sed -i "s@{{TIMEZONE}}@${TIMEZONE}@g" ${TMP}/iso_new/preseed/${SEED_FILE}

# Calculate checksum for seed file
seed_checksum=$(md5sum ${TMP}/iso_new/preseed/${SEED_FILE})

# Add the autoinstall option to the menu
sed -i "/label install/ilabel autoinstall\n\
  menu label ^Autoinstall CyanLab Ubuntu Server\n\
  kernel /install/vmlinuz\n\
  append file=/cdrom/preseed/ubuntu-server.seed initrd=/install/initrd.gz auto=true priority=high preseed/file=/cdrom/preseed/ubuntu.seed preseed/file/checksum=$seed_checksum --" ${TMP}/iso_new/isolinux/txt.cfg

echo -e "\r\033[K\e[36mRemastering ISO ----- Complete\e[0m"

echo -ne "\e[36mCreating remastered ISO\e[0m"
cd ${TMP}/iso_new
(mkisofs -D -r -V "CyanLab_UBUNTU" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${TMP}/${NEW_ISO_NAME} . > /dev/null 2>&1) &
spinner $!

# Make iso bootable (for dd'ing to  USB stick)
if [[ $BOOTABLE == "yes" ]] || [[ $BOOTABLE == "y" ]]; then
    isohybrid ${TMP}/${NEW_ISO_NAME}
fi
echo -e "\r\033[K\e[36mCreating remastered ISO ----- Complete\e[0m"

echo -ne "\e[36mCleaning Up\e[0m"
# Cleanup
umount ${TMP}/iso_org
rm -rf ${TMP}/iso_new
rm -rf ${TMP}/iso_org
rm -rf ${TMPHTML}
rm ${TMPHTML}
rm ${SEED_FILE}
echo -e "\r\033[K\e[36mCleaning Up ----- Complete\e[0m"

echo
echo

# Print info to user
echo -e "\e[36m---------------------------------------\e[0m"
echo -e "\e[36mThe new ISO File is located at: ${TMP}/${NEW_ISO_NAME}\e[0m"
echo -e "\e[36mYour USERNAME is: ${USERNAME}\e[0m"
echo -e "\e[36mYour PASSWORD is: ${PASSWORD}\e[0m"
echo -e "\e[36mYour HOSTNAME is: ${HOSTNAME}\e[0m"
echo -e "\e[36mYour TIMEZONE is: ${TIMEZONE}\e[0m"
echo

# Unset vars
unset USERNAME
unset PASSWORD
unset HOSTNAME
unset TIMEZONE
unset PWHASH
unset DOWNLOAD_FILE
unset DOWNLOAD_LOCATION
unset NEW_ISO_NAME
unset TMP
unset SEED_FILE