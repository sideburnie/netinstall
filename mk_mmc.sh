#!/bin/bash -e
#
# Copyright (c) 2009-2012 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#Notes: need to check for: parted, fdisk, wget, mkfs.*, mkimage, md5sum

unset MMC
unset FIRMWARE
unset SERIAL_MODE
unset USE_BETA_BOOTLOADER
unset BETA_KERNEL
unset EXPERIMENTAL_KERNEL
unset PRINTK
unset SPL_BOOT
unset BOOTLOADER
unset SMSC95XX_MOREMEM
unset DD_UBOOT
unset KERNEL_DEB
unset USE_UENV
unset ADDON

GIT_VERSION=$(git rev-parse --short HEAD)
IN_VALID_UBOOT=1

#Should now be fixed, more b4 removal..
#DI_BROKEN_USE_CROSS=1
unset DI_BROKEN_USE_CROSS

MIRROR="http://rcn-ee.net/deb/"
BACKUP_MIRROR="http://rcn-ee.homeip.net:81/dl/mirrors/deb/"
unset RCNEEDOWN

DIST=squeeze
ARCH=armel
DISTARCH="${DIST}-${ARCH}"

BOOT_LABEL=boot
PARTITION_PREFIX=""

#06-Oct-2010
#http://ports.ubuntu.com/dists/maverick/main/installer-armel/
MAVERICK_NETIMAGE="current"
MAVERICK_MD5SUM="12c0f04da6b8fb118939489f237e4c86"

#21-Apr-2011
#http://ports.ubuntu.com/dists/natty/main/installer-armel/
NATTY_NETIMAGE="current"
NATTY_MD5SUM="a88f348be5c94873be0d67a9ce8e485e"

#08-Oct-2011
#http://ports.ubuntu.com/dists/oneiric/main/installer-armel/
ONEIRIC_NETIMAGE="current"
ONEIRIC_MD5SUM="3a8978191d7a0544e229de54e4cc8e76"

#05-Feb-2012
#http://ports.ubuntu.com/dists/precise/main/installer-armel/
PRECISE_ARMEL_NETIMAGE="20101020ubuntu104"
PRECISE_ARMEL_MD5SUM="49d89d0e31669a38585fd2edc26cbe29"

#05-Feb-2012
#http://ports.ubuntu.com/dists/precise/main/installer-armhf/
PRECISE_ARMHF_NETIMAGE="20101020ubuntu104"
PRECISE_ARMHF_MD5SUM="e3b349ecd6c774829daf4315568b1843"

#22-Jan-2012: 6.0.4
#http://ftp.us.debian.org/debian/dists/squeeze/main/installer-armel/
SQUEEZE_NETIMAGE="20110106+squeeze4"
SQUEEZE_MD5SUM="f8d7e14b73c1cb89ff09c79a02694c22"

#http://ftp.us.debian.org/debian/dists/wheezy/main/installer-armel/
#http://ftp.us.debian.org/debian/dists/wheezy/main/installer-armhf/

DIR="$PWD"
TEMPDIR=$(mktemp -d)

function is_element_of {
	testelt=$1
	for validelt in $2 ; do
		[ $testelt = $validelt ] && return 0
	done
	return 1
}

#########################################################################
#
#  Define valid "--addon" values.
#
#########################################################################

VALID_ADDONS="pico ulcd"

function is_valid_addon {
	if is_element_of $1 "${VALID_ADDONS}" ] ; then
		return 0
	else
		return 1
	fi
}

function check_root {
if [[ $UID -ne 0 ]]; then
 echo "$0 must be run as sudo user or root"
 exit
fi
}

function find_issue {

check_root

#Software Qwerks

#Check for gnu-fdisk
#FIXME: GNU Fdisk seems to halt at "Using /dev/xx" when trying to script it..
if fdisk -v | grep "GNU Fdisk" >/dev/null ; then
 echo "Sorry, this script currently doesn't work with GNU Fdisk"
 exit
fi

unset PARTED_ALIGN
if parted -v | grep parted | grep 2.[1-3] >/dev/null ; then
 PARTED_ALIGN="--align cylinder"
fi
}

function detect_software {

echo "This script needs:"
echo "Ubuntu/Debian: sudo apt-get install uboot-mkimage wget dosfstools parted"
echo "Fedora: as root: yum install uboot-tools wget dosfstools parted dpkg patch"
echo "Gentoo: emerge u-boot-tools wget dosfstools parted dpkg"
echo ""

unset NEEDS_PACKAGE

if [ ! $(which mkimage) ];then
 echo "Missing uboot-mkimage"
 NEEDS_PACKAGE=1
fi

if [ ! $(which wget) ];then
 echo "Missing wget"
 NEEDS_PACKAGE=1
fi

if [ ! $(which mkfs.vfat) ];then
 echo "Missing mkfs.vfat"
 NEEDS_PACKAGE=1
fi

if [ ! $(which parted) ];then
 echo "Missing parted"
 NEEDS_PACKAGE=1
fi

if [ ! $(which dpkg) ];then
 echo "Missing dpkg"
 NEEDS_PACKAGE=1
fi

if [ ! $(which patch) ];then
 echo "Missing patch"
 NEEDS_PACKAGE=1
fi

if [ "${NEEDS_PACKAGE}" ];then
 echo ""
 echo "Your System is Missing some dependencies"
 echo ""
 exit
fi

}

function rcn-ee_down_use_mirror {
	echo ""
	echo "rcn-ee.net down, switching to slower backup mirror"
	echo "-----------------------------"
	MIRROR=${BACKUP_MIRROR}
	RCNEEDOWN=1
}

function dl_bootloader {
 echo ""
 echo "Downloading Device's Bootloader"
 echo "-----------------------------"

 mkdir -p ${TEMPDIR}/dl/${DISTARCH}
 mkdir -p "${DIR}/dl/${DISTARCH}"

	echo "Checking rcn-ee.net to see if server is up and responding to pings..."
	ping -c 3 -w 10 www.rcn-ee.net | grep "ttl=" &> /dev/null || rcn-ee_down_use_mirror

 wget --no-verbose --directory-prefix=${TEMPDIR}/dl/ ${MIRROR}tools/latest/bootloader

	if [ "$RCNEEDOWN" ];then
		sed -i -e "s/rcn-ee.net/rcn-ee.homeip.net:81/g" ${TEMPDIR}/dl/bootloader
		sed -i -e 's:81/deb/:81/dl/mirrors/deb/:g' ${TEMPDIR}/dl/bootloader
	fi

 if [ "$USE_BETA_BOOTLOADER" ];then
  ABI="ABX2"
 else
  ABI="ABI2"
 fi

 if [ "${SPL_BOOT}" ] ; then
  MLO=$(cat ${TEMPDIR}/dl/bootloader | grep "${ABI}:${BOOTLOADER}:SPL" | awk '{print $2}')
  wget --no-verbose  --directory-prefix=${TEMPDIR}/dl/ ${MLO}
  MLO=${MLO##*/}
  echo "SPL Bootloader: ${MLO}"
 fi

	UBOOT=$(cat ${TEMPDIR}/dl/bootloader | grep "${ABI}:${BOOTLOADER}:BOOT" | awk '{print $2}')
	wget --directory-prefix=${TEMPDIR}/dl/ ${UBOOT}
	UBOOT=${UBOOT##*/}
	echo "UBOOT Bootloader: ${UBOOT}"
}

function dl_kernel_image {
 echo ""
 echo "Downloading Device's Kernel Image"
 echo "-----------------------------"

 KERNEL_SEL="STABLE"

 if [ "$BETA_KERNEL" ];then
  KERNEL_SEL="TESTING"
 fi

 if [ "$EXPERIMENTAL_KERNEL" ];then
  KERNEL_SEL="EXPERIMENTAL"
 fi

 if [ ! "${KERNEL_DEB}" ] ; then
  wget --no-verbose --directory-prefix=${TEMPDIR}/dl/ ${MIRROR}${DIST}-${ARCH}/LATEST-${SUBARCH}

		if [ "$RCNEEDOWN" ] ; then
			sed -i -e "s/rcn-ee.net/rcn-ee.homeip.net:81/g" ${TEMPDIR}/dl/LATEST-${SUBARCH}
			sed -i -e 's:81/deb/:81/dl/mirrors/deb/:g' ${TEMPDIR}/dl/LATEST-${SUBARCH}
		fi

		FTP_DIR=$(cat ${TEMPDIR}/dl/LATEST-${SUBARCH} | grep "ABI:1 ${KERNEL_SEL}" | awk '{print $3}')
		if [ "$RCNEEDOWN" ] ; then
			#http://rcn-ee.homeip.net:81/dl/mirrors/deb/squeeze-armel/v3.2.6-x4/install-me.sh
			FTP_DIR=$(echo ${FTP_DIR} | awk -F'/' '{print $8}')
		else
			#http://rcn-ee.net/deb/squeeze-armel/v3.2.6-x4/install-me.sh
			FTP_DIR=$(echo ${FTP_DIR} | awk -F'/' '{print $6}')
		fi
		KERNEL=$(echo ${FTP_DIR} | sed 's/v//')

		wget --no-verbose --directory-prefix=${TEMPDIR}/dl/ ${MIRROR}${DIST}-${ARCH}/${FTP_DIR}/
		ACTUAL_DEB_FILE=$(cat ${TEMPDIR}/dl/index.html | grep linux-image)
		ACTUAL_DEB_FILE=$(echo ${ACTUAL_DEB_FILE} | awk -F ".deb" '{print $1}')
		ACTUAL_DEB_FILE=${ACTUAL_DEB_FILE##*linux-image-}
		ACTUAL_DEB_FILE="linux-image-${ACTUAL_DEB_FILE}.deb"

  wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" ${MIRROR}${DIST}-${ARCH}/v${KERNEL}/${ACTUAL_DEB_FILE}
  if [ "${DI_BROKEN_USE_CROSS}" ] ; then
   CROSS_DEB_FILE=$(echo ${ACTUAL_DEB_FILE} | sed 's:'${DIST}':cross:g')
   wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" ${MIRROR}cross/v${KERNEL}/${CROSS_DEB_FILE}
  fi
 else
  KERNEL=${DEB_FILE}
  #Remove all "\" from file name.
  ACTUAL_DEB_FILE=$(echo ${DEB_FILE} | sed 's!.*/!!' | grep linux-image)
  cp -v ${DEB_FILE} "${DIR}/dl/${DISTARCH}/"
 fi

 echo "Using: ${ACTUAL_DEB_FILE}"
}

function remove_uboot_wrapper {
 echo "Note: NetInstall has u-boot header, removing..."
 echo "-----------------------------"
 dd if="${DIR}/dl/${DISTARCH}/${NETINSTALL}" bs=64 skip=1 of="${DIR}/dl/${DISTARCH}/initrd.gz"
 echo "-----------------------------"
 NETINSTALL="initrd.gz"
 unset UBOOTWRAPPER
}

function actually_dl_netinstall {
 wget --directory-prefix="${DIR}/dl/${DISTARCH}" ${HTTP_IMAGE}/${DIST}/main/installer-${ARCH}/${NETIMAGE}/images/${BASE_IMAGE}/netboot/${NETINSTALL}
 MD5SUM=$(md5sum "${DIR}/dl/${DISTARCH}/${NETINSTALL}" | awk '{print $1}')
 if [ "${UBOOTWRAPPER}" ]; then
  remove_uboot_wrapper
 fi
}

function check_dl_netinstall {
 MD5SUM=$(md5sum "${DIR}/dl/${DISTARCH}/${NETINSTALL}" | awk '{print $1}')
 if [ "=$TEST_MD5SUM=" != "=$MD5SUM=" ]; then
  echo "Note: NetInstall md5sum has changed: $MD5SUM"
  echo "-----------------------------"
  rm -f "${DIR}/dl/${DISTARCH}/${NETINSTALL}" || true
  actually_dl_netinstall
 else
  if [ "${UBOOTWRAPPER}" ]; then
   remove_uboot_wrapper
  fi
 fi
}

function dl_netinstall_image {
 echo ""
 echo "Downloading NetInstall Image"
 echo "-----------------------------"

 unset UBOOTWRAPPER

case "$DISTARCH" in
    maverick-armel)
	TEST_MD5SUM=$MAVERICK_MD5SUM
	NETIMAGE=$MAVERICK_NETIMAGE
	HTTP_IMAGE="http://ports.ubuntu.com/ubuntu-ports/dists"
	BASE_IMAGE="versatile"
	NETINSTALL="initrd.gz"
        ;;
    natty-armel)
	TEST_MD5SUM=$NATTY_MD5SUM
	NETIMAGE=$NATTY_NETIMAGE
	HTTP_IMAGE="http://ports.ubuntu.com/ubuntu-ports/dists"
	BASE_IMAGE="versatile"
	NETINSTALL="initrd.gz"
        ;;
    oneiric-armel)
	TEST_MD5SUM=$ONEIRIC_MD5SUM
	NETIMAGE=$ONEIRIC_NETIMAGE
	HTTP_IMAGE="http://ports.ubuntu.com/ubuntu-ports/dists"
	BASE_IMAGE="linaro-vexpress"
	NETINSTALL="initrd.gz"
        ;;
    precise-armel)
	TEST_MD5SUM=$PRECISE_ARMEL_MD5SUM
	NETIMAGE=$PRECISE_ARMEL_NETIMAGE
	HTTP_IMAGE="http://ports.ubuntu.com/ubuntu-ports/dists"
	BASE_IMAGE="linaro-vexpress"
	NETINSTALL="initrd.gz"
        ;;
    precise-armhf)
	TEST_MD5SUM=$PRECISE_ARMHF_MD5SUM
	NETIMAGE=$PRECISE_ARMHF_NETIMAGE
	HTTP_IMAGE="http://ports.ubuntu.com/ubuntu-ports/dists"
	BASE_IMAGE="omap"
    UBOOTWRAPPER=1
	NETINSTALL="uInitrd"
        ;;
    squeeze-armel)
	TEST_MD5SUM=$SQUEEZE_MD5SUM
	NETIMAGE=$SQUEEZE_NETIMAGE
	HTTP_IMAGE="http://ftp.debian.org/debian/dists"
	BASE_IMAGE="versatile"
	NETINSTALL="initrd.gz"
        ;;
esac

 if [ -f "${DIR}/dl/${DISTARCH}/${NETINSTALL}" ]; then
  check_dl_netinstall
 else
  actually_dl_netinstall
 fi

 echo "md5sum of NetInstall: ${MD5SUM}"
}

function dl_firmware {
 echo ""
 echo "Downloading Firmware"
 echo "-----------------------------"

 #TODO: We should just use the git tree blobs over distro versions
 if [ ! -f "${DIR}/dl/linux-firmware/.git/config" ]; then
  cd "${DIR}/dl/"
  git clone git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git
  cd "${DIR}/"
 else
  cd "${DIR}/dl/linux-firmware"
  #convert to new repo, if still using dwmw2's..
  cat "${DIR}/dl/linux-firmware/.git/config" | grep dwmw2 && sed -i -e 's:dwmw2:firmware:g' "${DIR}/dl/linux-firmware/.git/config"
  git pull
  cd "${DIR}/"
 fi

case "$DIST" in
    maverick)
	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ http://ports.ubuntu.com/pool/main/l/linux-firmware/
	MAVERICK_FW=$(cat ${TEMPDIR}/dl/index.html | grep linux-firmware | grep _all.deb | tail -1 | awk -F"\"" '{print $8}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://ports.ubuntu.com/pool/main/l/linux-firmware/${MAVERICK_FW}
	MAVERICK_FW=${MAVERICK_FW##*/}

	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ http://ports.ubuntu.com/pool/multiverse/l/linux-firmware-nonfree/
	MAVERICK_NONF_FW=$(cat ${TEMPDIR}/dl/index.html | grep linux-firmware-nonfree | grep _all.deb | tail -1 | awk -F"\"" '{print $8}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://ports.ubuntu.com/pool/multiverse/l/linux-firmware-nonfree/${MAVERICK_NONF_FW}
	MAVERICK_NONF_FW=${MAVERICK_NONF_FW##*/}

	#V3.1 needs 1.9.4 for ar9170
	#wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://www.kernel.org/pub/linux/kernel/people/chr/carl9170/fw/1.9.4/carl9170-1.fw
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://rcn-ee.net/firmware/carl9170/1.9.4/carl9170-1.fw
	AR9170_FW="carl9170-1.fw"
        ;;
    natty)
	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ http://ports.ubuntu.com/pool/main/l/linux-firmware/
	NATTY_FW=$(cat ${TEMPDIR}/dl/index.html | grep linux-firmware | grep _all.deb | tail -1 | awk -F"\"" '{print $8}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://ports.ubuntu.com/pool/main/l/linux-firmware/${NATTY_FW}
	NATTY_FW=${NATTY_FW##*/}

	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ http://ports.ubuntu.com/pool/multiverse/l/linux-firmware-nonfree/
	NATTY_NONF_FW=$(cat ${TEMPDIR}/dl/index.html | grep linux-firmware-nonfree | grep _all.deb | tail -1 | awk -F"\"" '{print $8}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://ports.ubuntu.com/pool/multiverse/l/linux-firmware-nonfree/${NATTY_NONF_FW}
	NATTY_NONF_FW=${NATTY_NONF_FW##*/}

	#V3.1 needs 1.9.4 for ar9170
	#wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://www.kernel.org/pub/linux/kernel/people/chr/carl9170/fw/1.9.4/carl9170-1.fw
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://rcn-ee.net/firmware/carl9170/1.9.4/carl9170-1.fw
	AR9170_FW="carl9170-1.fw"
        ;;
    oneiric)
	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ http://ports.ubuntu.com/pool/main/l/linux-firmware/
	ONEIRIC_FW=$(cat ${TEMPDIR}/dl/index.html | grep linux-firmware | grep _all.deb | tail -1 | awk -F"\"" '{print $8}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://ports.ubuntu.com/pool/main/l/linux-firmware/${ONEIRIC_FW}
	ONEIRIC_FW=${ONEIRIC_FW##*/}

	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ http://ports.ubuntu.com/pool/multiverse/l/linux-firmware-nonfree/
	ONEIRIC_NONF_FW=$(cat ${TEMPDIR}/dl/index.html | grep linux-firmware-nonfree | grep _all.deb | tail -1 | awk -F"\"" '{print $8}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://ports.ubuntu.com/pool/multiverse/l/linux-firmware-nonfree/${ONEIRIC_NONF_FW}
	ONEIRIC_NONF_FW=${ONEIRIC_NONF_FW##*/}

	#V3.1 needs 1.9.4 for ar9170
	#wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://www.kernel.org/pub/linux/kernel/people/chr/carl9170/fw/1.9.4/carl9170-1.fw
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://rcn-ee.net/firmware/carl9170/1.9.4/carl9170-1.fw
	AR9170_FW="carl9170-1.fw"
        ;;
    precise)
	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ http://ports.ubuntu.com/pool/main/l/linux-firmware/
	PRECISE_FW=$(cat ${TEMPDIR}/dl/index.html | grep linux-firmware | grep _all.deb | tail -1 | awk -F"\"" '{print $8}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://ports.ubuntu.com/pool/main/l/linux-firmware/${PRECISE_FW}
	PRECISE_FW=${PRECISE_FW##*/}

	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ http://ports.ubuntu.com/pool/multiverse/l/linux-firmware-nonfree/
	PRECISE_NONF_FW=$(cat ${TEMPDIR}/dl/index.html | grep linux-firmware-nonfree | grep _all.deb | tail -1 | awk -F"\"" '{print $8}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://ports.ubuntu.com/pool/multiverse/l/linux-firmware-nonfree/${PRECISE_NONF_FW}
	PRECISE_NONF_FW=${PRECISE_NONF_FW##*/}

	#V3.1 needs 1.9.4 for ar9170
	#wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://www.kernel.org/pub/linux/kernel/people/chr/carl9170/fw/1.9.4/carl9170-1.fw
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://rcn-ee.net/firmware/carl9170/1.9.4/carl9170-1.fw
	AR9170_FW="carl9170-1.fw"
        ;;
    squeeze)
	#from: http://packages.debian.org/source/squeeze/firmware-nonfree

	#Atmel
	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ ftp://ftp.us.debian.org/debian/pool/non-free/a/atmel-firmware/
	ATMEL_FW=$(cat ${TEMPDIR}/dl/index.html | grep atmel | grep -v diff.gz | grep -v .dsc | grep -v orig.tar.gz | tail -1 | awk -F"\"" '{print $2}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" ${ATMEL_FW}
	ATMEL_FW=${ATMEL_FW##*/}

	#Ralink
	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ ftp://ftp.us.debian.org/debian/pool/non-free/f/firmware-nonfree/
	RALINK_FW=$(cat ${TEMPDIR}/dl/index.html | grep ralink | grep -v lenny | tail -1 | awk -F"\"" '{print $2}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" ${RALINK_FW}
	RALINK_FW=${RALINK_FW##*/}

	#libertas
	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ ftp://ftp.us.debian.org/debian/pool/non-free/libe/libertas-firmware/
	LIBERTAS_FW=$(cat ${TEMPDIR}/dl/index.html | grep libertas | grep -v diff.gz | grep -v .dsc | grep -v orig.tar.gz | tail -1 | awk -F"\"" '{print $2}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" ${LIBERTAS_FW}
	LIBERTAS_FW=${LIBERTAS_FW##*/}

	#zd1211
	rm -f ${TEMPDIR}/dl/index.html || true
	wget --directory-prefix=${TEMPDIR}/dl/ ftp://ftp.us.debian.org/debian/pool/non-free/z/zd1211-firmware/
	ZD1211_FW=$(cat ${TEMPDIR}/dl/index.html | grep zd1211 | grep -v diff.gz | grep -v tar.gz | grep -v .dsc | tail -1 | awk -F"\"" '{print $2}')
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" ${ZD1211_FW}
	ZD1211_FW=${ZD1211_FW##*/}

	#V3.1 needs 1.9.4 for ar9170
	#wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://www.kernel.org/pub/linux/kernel/people/chr/carl9170/fw/1.9.4/carl9170-1.fw
	wget -c --directory-prefix="${DIR}/dl/${DISTARCH}" http://rcn-ee.net/firmware/carl9170/1.9.4/carl9170-1.fw
	AR9170_FW="carl9170-1.fw"
        ;;
esac

}

function boot_files_template {

cat > ${TEMPDIR}/bootscripts/netinstall.cmd <<netinstall_boot_cmd
SCR_FB
SCR_TIMING
SCR_VRAM
setenv console DICONSOLE
setenv mmcroot /dev/ram0 rw
setenv bootcmd 'fatload mmc 0:1 UIMAGE_ADDR uImage.net; fatload mmc 0:1 UINITRD_ADDR uInitrd.net; bootm UIMAGE_ADDR UINITRD_ADDR'
setenv bootargs console=\${console} root=\${mmcroot} VIDEO_DISPLAY
boot
netinstall_boot_cmd

cat > ${TEMPDIR}/bootscripts/normal.cmd <<normal_boot_cmd
SCR_FB
SCR_TIMING
SCR_VRAM
setenv console SERIAL_CONSOLE
setenv optargs VIDEO_CONSOLE
setenv mmcroot FINAL_PART ro
setenv mmcrootfstype FINAL_FSTYPE rootwait fixrtc
setenv bootcmd 'fatload mmc 0:1 UIMAGE_ADDR uImage; fatload mmc 0:1 UINITRD_ADDR uInitrd; bootm UIMAGE_ADDR UINITRD_ADDR'
setenv bootargs console=\${console} \${optargs} root=\${mmcroot} rootfstype=\${mmcrootfstype} VIDEO_DISPLAY
boot
normal_boot_cmd

}

function boot_scr_to_uenv_txt {

cat > ${TEMPDIR}/bootscripts/uEnv.cmd <<uenv_boot_cmd
bootenv=boot.scr
loaduimage=fatload mmc \${mmcdev} \${loadaddr} \${bootenv}
mmcboot=echo Running boot.scr script from mmc ...; source \${loadaddr}
uenv_boot_cmd

}

function boot_uenv_txt_template {
#(rcn-ee)in a way these are better then boot.scr, but each target is going to have a slightly different entry point..

cat > ${TEMPDIR}/bootscripts/netinstall.cmd <<uenv_generic_netinstall_cmd
bootfile=uImage.net
bootinitrd=uInitrd.net
address_uimage=UIMAGE_ADDR
address_uinitrd=UINITRD_ADDR

UENV_VRAM

console=DICONSOLE

UENV_FB
UENV_TIMING

mmcroot=/dev/ram0 rw

mmc_load_uinitrd=fatload mmc 0:1 \${address_uinitrd} \${bootinitrd}
uenv_generic_netinstall_cmd


cat > ${TEMPDIR}/bootscripts/normal.cmd <<uenv_generic_normalboot_cmd
bootfile=uImage
bootinitrd=uInitrd
address_uimage=UIMAGE_ADDR
address_uinitrd=UINITRD_ADDR

UENV_VRAM

console=SERIAL_CONSOLE

UENV_FB
UENV_TIMING

mmcroot=FINAL_PART ro
mmcrootfstype=FINAL_FSTYPE rootwait fixrtc

mmc_load_uinitrd=fatload mmc 0:1 \${address_uinitrd} \${bootinitrd}
uenv_generic_normalboot_cmd

if test "-$ADDON-" = "-ulcd-"
then

cat >> ${TEMPDIR}/bootscripts/netinstall.cmd <<ulcd_uenv_netinstall_cmd

lcd1=i2c mw 40 00 00; i2c mw 40 04 80; i2c mw 40 0d 05
uenvcmd=i2c dev 1; run lcd1; i2c dev 0

ulcd_uenv_netinstall_cmd

cat >> ${TEMPDIR}/bootscripts/normal.cmd <<ulcd_uenv_normalboot_cmd

lcd1=i2c mw 40 00 00; i2c mw 40 04 80; i2c mw 40 0d 05
uenvcmd=i2c dev 1; run lcd1; i2c dev 0

ulcd_uenv_normalboot_cmd
fi

case "$SYSTEM" in
    beagle_bx)

cat >> ${TEMPDIR}/bootscripts/netinstall.cmd <<uenv_netinstall_cmd
mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} mpurate=\${mpurate} buddy=\${buddy} VIDEO_DISPLAY root=\${mmcroot} musb_hdrc.fifo_mode=5

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_netinstall_cmd

cat >> ${TEMPDIR}/bootscripts/normal.cmd <<uenv_normalboot_cmd
optargs=VIDEO_CONSOLE

mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} \${optargs} mpurate=\${mpurate} buddy=\${buddy} buddy2=\${buddy2} VIDEO_DISPLAY root=\${mmcroot} rootfstype=\${mmcrootfstype} musb_hdrc.fifo_mode=5

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_normalboot_cmd
        ;;
    beagle_cx)

cat >> ${TEMPDIR}/bootscripts/netinstall.cmd <<uenv_netinstall_cmd
mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} mpurate=\${mpurate} buddy=\${buddy} buddy2=\${buddy2} camera=\${camera} VIDEO_DISPLAY root=\${mmcroot}

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_netinstall_cmd

cat >> ${TEMPDIR}/bootscripts/normal.cmd <<uenv_normalboot_cmd
optargs=VIDEO_CONSOLE

mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} \${optargs} mpurate=\${mpurate} buddy=\${buddy} buddy2=\${buddy2} camera=\${camera} VIDEO_DISPLAY root=\${mmcroot} rootfstype=\${mmcrootfstype}

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_normalboot_cmd
        ;;
    beagle_xm)

cat >> ${TEMPDIR}/bootscripts/netinstall.cmd <<uenv_netinstall_cmd
mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} mpurate=\${mpurate} buddy=\${buddy} buddy2=\${buddy2} camera=\${camera} VIDEO_DISPLAY root=\${mmcroot}

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_netinstall_cmd

cat >> ${TEMPDIR}/bootscripts/normal.cmd <<uenv_normalboot_cmd
optargs=VIDEO_CONSOLE

mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} \${optargs} mpurate=\${mpurate} buddy=\${buddy} buddy2=\${buddy2} camera=\${camera} VIDEO_DISPLAY root=\${mmcroot} rootfstype=\${mmcrootfstype}

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_normalboot_cmd
        ;;
    crane)

cat >> ${TEMPDIR}/bootscripts/netinstall.cmd <<uenv_netinstall_cmd
mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} VIDEO_DISPLAY root=\${mmcroot}

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_netinstall_cmd

cat >> ${TEMPDIR}/bootscripts/normal.cmd <<uenv_normalboot_cmd
optargs=VIDEO_CONSOLE

mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} \${optargs} VIDEO_DISPLAY root=\${mmcroot} rootfstype=\${mmcrootfstype}

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_normalboot_cmd
        ;;
    panda)

cat >> ${TEMPDIR}/bootscripts/netinstall.cmd <<uenv_netinstall_cmd
mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} VIDEO_DISPLAY root=\${mmcroot}

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_netinstall_cmd

cat >> ${TEMPDIR}/bootscripts/normal.cmd <<uenv_normalboot_cmd
optargs=VIDEO_CONSOLE

mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} \${optargs} VIDEO_DISPLAY root=\${mmcroot} rootfstype=\${mmcrootfstype}

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_normalboot_cmd
        ;;
    panda_es)

cat >> ${TEMPDIR}/bootscripts/netinstall.cmd <<uenv_netinstall_cmd
mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} VIDEO_DISPLAY root=\${mmcroot}

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_netinstall_cmd

cat >> ${TEMPDIR}/bootscripts/normal.cmd <<uenv_normalboot_cmd
optargs=VIDEO_CONSOLE

mmc_load_uimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmcargs=setenv bootargs console=\${console} \${optargs} VIDEO_DISPLAY root=\${mmcroot} rootfstype=\${mmcrootfstype}

loaduimage=printenv; run mmc_load_uimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmcargs; bootm \${address_uimage} \${address_uinitrd}
uenv_normalboot_cmd
        ;;
    bone)

cat >> ${TEMPDIR}/bootscripts/netinstall.cmd <<uenv_netinstall_cmd
rcn_mmcloaduimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmc_args=run bootargs_defaults;setenv bootargs \${bootargs} root=\${mmcroot}

mmc_load_uimage=printenv; run rcn_mmcloaduimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmc_args; bootm \${address_uimage} \${address_uinitrd}
uenv_netinstall_cmd

cat >> ${TEMPDIR}/bootscripts/normal.cmd <<uenv_normalboot_cmd
rcn_mmcloaduimage=fatload mmc 0:1 \${address_uimage} \${bootfile}

mmc_args=run bootargs_defaults;setenv bootargs \${bootargs} root=\${mmcroot} rootfstype=\${mmcrootfstype} ip=\${ip_method}

mmc_load_uimage=run rcn_mmcloaduimage; run mmc_load_uinitrd; echo Booting from mmc ...; run mmc_args; bootm \${address_uimage} \${address_uinitrd}
uenv_normalboot_cmd
        ;;
esac

}

function tweak_boot_scripts {
 #debug -|-
# echo "NetInstall Boot Script: Generic"
# echo "-----------------------------"
# cat ${TEMPDIR}/bootscripts/netinstall.cmd

 if test "-$ADDON-" = "-pico-"
 then
  VIDEO_TIMING="640x480MR-16@60"
 fi

 if test "-$ADDON-" = "-ulcd-"
 then
  VIDEO_TIMING="800x480MR-16@60"
 fi

 if [ "$SVIDEO_NTSC" ];then
  VIDEO_TIMING="ntsc"
  VIDEO_OMAPFB_MODE=tv
 fi

 if [ "$SVIDEO_PAL" ];then
  VIDEO_TIMING="pal"
  VIDEO_OMAPFB_MODE=tv
 fi

 #Set uImage boot address
 sed -i -e 's:UIMAGE_ADDR:'$UIMAGE_ADDR':g' ${TEMPDIR}/bootscripts/*.cmd

 #Set uInitrd boot address
 sed -i -e 's:UINITRD_ADDR:'$UINITRD_ADDR':g' ${TEMPDIR}/bootscripts/*.cmd

 #Set the Serial Console
 sed -i -e 's:SERIAL_CONSOLE:'$SERIAL_CONSOLE':g' ${TEMPDIR}/bootscripts/*.cmd

 if [ "${IS_OMAP}" ] ; then
  #setenv defaultdisplay VIDEO_OMAPFB_MODE
  #setenv dvimode VIDEO_TIMING
  #setenv vram VIDEO_OMAP_RAM
  sed -i -e 's:SCR_VRAM:setenv vram VIDEO_OMAP_RAM:g' ${TEMPDIR}/bootscripts/*.cmd
  sed -i -e 's:SCR_FB:setenv defaultdisplay VIDEO_OMAPFB_MODE:g' ${TEMPDIR}/bootscripts/*.cmd
  sed -i -e 's:SCR_TIMING:setenv dvimode VIDEO_TIMING:g' ${TEMPDIR}/bootscripts/*.cmd

  #defaultdisplay=VIDEO_OMAPFB_MODE
  #dvimode=VIDEO_TIMING
  #vram=VIDEO_OMAP_RAM
  sed -i -e 's:UENV_VRAM:vram=VIDEO_OMAP_RAM:g' ${TEMPDIR}/bootscripts/*.cmd
  sed -i -e 's:UENV_FB:defaultdisplay=VIDEO_OMAPFB_MODE:g' ${TEMPDIR}/bootscripts/*.cmd
  sed -i -e 's:UENV_TIMING:dvimode=VIDEO_TIMING:g' ${TEMPDIR}/bootscripts/*.cmd

  #vram=\${vram} omapfb.mode=\${defaultdisplay}:\${dvimode} omapdss.def_disp=\${defaultdisplay}
  sed -i -e 's:VIDEO_DISPLAY:TMP_VRAM TMP_OMAPFB TMP_OMAPDSS:g' ${TEMPDIR}/bootscripts/*.cmd
  sed -i -e 's:TMP_VRAM:'vram=\${vram}':g' ${TEMPDIR}/bootscripts/*.cmd
  sed -i -e 's/TMP_OMAPFB/'omapfb.mode=\${defaultdisplay}:\${dvimode}'/g' ${TEMPDIR}/bootscripts/*.cmd
  sed -i -e 's:TMP_OMAPDSS:'omapdss.def_disp=\${defaultdisplay}':g' ${TEMPDIR}/bootscripts/*.cmd

  FILE="netinstall.cmd"
  if [ "$SERIAL_MODE" ];then
   #Set the Serial Console: console=CONSOLE
   sed -i -e 's:DICONSOLE:'$SERIAL_CONSOLE':g' ${TEMPDIR}/bootscripts/${FILE}

   #omap3/4: In serial mode, NetInstall needs all traces of VIDEO removed..
   #drop: vram=\${vram}
   sed -i -e 's:'vram=\${vram}' ::g' ${TEMPDIR}/bootscripts/${FILE}

   #omapfb.mode=\${defaultdisplay}:\${dvimode} omapdss.def_disp=\${defaultdisplay}
   sed -i -e 's:'\${defaultdisplay}'::g' ${TEMPDIR}/bootscripts/${FILE}
   sed -i -e 's:'\${dvimode}'::g' ${TEMPDIR}/bootscripts/${FILE}
   #omapfb.mode=: omapdss.def_disp=
   sed -i -e "s/omapfb.mode=: //g" ${TEMPDIR}/bootscripts/${FILE}
   #uenv seems to have an extra space (beagle_xm)
   sed -i -e 's:omapdss.def_disp= ::g' ${TEMPDIR}/bootscripts/${FILE}
   sed -i -e 's:omapdss.def_disp=::g' ${TEMPDIR}/bootscripts/${FILE}
  else
   #Set the Video Console
   sed -i -e 's:DICONSOLE:tty0:g' ${TEMPDIR}/bootscripts/${FILE}
   sed -i -e 's:VIDEO_CONSOLE:console=tty0:g' ${TEMPDIR}/bootscripts/${FILE}

   sed -i -e 's:VIDEO_OMAP_RAM:'$VIDEO_OMAP_RAM':g' ${TEMPDIR}/bootscripts/${FILE}
   sed -i -e 's:VIDEO_OMAPFB_MODE:'$VIDEO_OMAPFB_MODE':g' ${TEMPDIR}/bootscripts/${FILE}
   sed -i -e 's:VIDEO_TIMING:'$VIDEO_TIMING':g' ${TEMPDIR}/bootscripts/${FILE}
  fi

  FILE="normal.cmd"
  #Video mode is always available after final install
  sed -i -e 's:DICONSOLE:tty0:g' ${TEMPDIR}/bootscripts/${FILE}
  sed -i -e 's:VIDEO_CONSOLE:console=tty0:g' ${TEMPDIR}/bootscripts/${FILE}

  sed -i -e 's:VIDEO_OMAP_RAM:'$VIDEO_OMAP_RAM':g' ${TEMPDIR}/bootscripts/${FILE}
  sed -i -e 's:VIDEO_OMAPFB_MODE:'$VIDEO_OMAPFB_MODE':g' ${TEMPDIR}/bootscripts/${FILE}
  sed -i -e 's:VIDEO_TIMING:'$VIDEO_TIMING':g' ${TEMPDIR}/bootscripts/${FILE}
 fi

 if [ "${IS_IMX}" ] ; then
  #not used:
  sed -i -e 's:SCR_VRAM::g' ${TEMPDIR}/bootscripts/*.cmd
  sed -i -e 's:UENV_VRAM::g' ${TEMPDIR}/bootscripts/*.cmd

  #setenv framebuffer VIDEO_FB
  #setenv dvimode VIDEO_TIMING
  sed -i -e 's:SCR_FB:setenv framebuffer VIDEO_FB:g' ${TEMPDIR}/bootscripts/*.cmd
  sed -i -e 's:SCR_TIMING:setenv dvimode VIDEO_TIMING:g' ${TEMPDIR}/bootscripts/*.cmd

  #framebuffer=VIDEO_FB
  #dvimode=VIDEO_TIMING
  sed -i -e 's:UENV_FB:framebuffer=VIDEO_FB:g' ${TEMPDIR}/bootscripts/*.cmd
  sed -i -e 's:UENV_TIMING:dvimode=VIDEO_TIMING:g' ${TEMPDIR}/bootscripts/*.cmd

  #video=\${framebuffer}:${dvimode}
  sed -i -e 's/VIDEO_DISPLAY/'video=\${framebuffer}:\${dvimode}'/g' ${TEMPDIR}/bootscripts/*.cmd

  FILE="netinstall.cmd"
  if [ "$SERIAL_MODE" ];then
   #Set the Serial Console: console=CONSOLE
   sed -i -e 's:DICONSOLE:'$SERIAL_CONSOLE':g' ${TEMPDIR}/bootscripts/${FILE}

   #mx53: In serial mode, NetInstall needs all traces of VIDEO removed..

   #video=\${framebuffer}:\${dvimode}
   sed -i -e 's:'\${framebuffer}'::g' ${TEMPDIR}/bootscripts/${FILE}
   sed -i -e 's:'\${dvimode}'::g' ${TEMPDIR}/bootscripts/${FILE}
   #video=:
   sed -i -e "s/video=: //g" ${TEMPDIR}/bootscripts/${FILE}
   sed -i -e "s/video=://g" ${TEMPDIR}/bootscripts/${FILE}
  else
   #Set the Video Console
   sed -i -e 's:DICONSOLE:tty0:g' ${TEMPDIR}/bootscripts/${FILE}
   sed -i -e 's:VIDEO_CONSOLE:console=tty0:g' ${TEMPDIR}/bootscripts/${FILE}

   sed -i -e 's:VIDEO_FB:'$VIDEO_FB':g' ${TEMPDIR}/bootscripts/${FILE}
   sed -i -e 's:VIDEO_TIMING:'$VIDEO_TIMING':g' ${TEMPDIR}/bootscripts/${FILE}
  fi

  FILE="normal.cmd"
  #Video mode is always available after final install
  sed -i -e 's:DICONSOLE:tty0:g' ${TEMPDIR}/bootscripts/${FILE}
  sed -i -e 's:VIDEO_CONSOLE:console=tty0:g' ${TEMPDIR}/bootscripts/${FILE}

  sed -i -e 's:VIDEO_FB:'$VIDEO_FB':g' ${TEMPDIR}/bootscripts/${FILE}
  sed -i -e 's:VIDEO_TIMING:'$VIDEO_TIMING':g' ${TEMPDIR}/bootscripts/${FILE}
 fi

 if [ "$PRINTK" ];then
  sed -i 's/bootargs/bootargs earlyprintk/g' ${TEMPDIR}/bootscripts/*.cmd
 fi

 #debug^
# echo "NetInstall Boot Script: Modified For Device"
# echo "-----------------------------"
# cat ${TEMPDIR}/bootscripts/netinstall.cmd
}

function setup_bootscripts {
 mkdir -p ${TEMPDIR}/bootscripts/

 if [ "$USE_UENV" ];then
  boot_uenv_txt_template
  tweak_boot_scripts
 else
  boot_files_template
  boot_scr_to_uenv_txt
  tweak_boot_scripts
 fi

 #Setup serial
 sed -i -e 's:SERIAL:'$SERIAL':g' "${DIR}/scripts/serial.conf"
 sed -i -e 's:SERIAL:'$SERIAL':g' "${DIR}/scripts/ubuntu-tweaks.diff"
 sed -i -e 's:SERIAL:'$SERIAL':g' "${DIR}/scripts/debian-tweaks.diff"

 #Setup Kernel Boot Address
 sed -i -e 's:ZRELADD:'$ZRELADD':g' "${DIR}/scripts/ubuntu-tweaks.diff"
 sed -i -e 's:ZRELADD:'$ZRELADD':g' "${DIR}/scripts/debian-tweaks.diff"
 sed -i -e 's:ZRELADD:'$ZRELADD':g' "${DIR}/scripts/ubuntu-finish.sh"
 sed -i -e 's:ZRELADD:'$ZRELADD':g' "${DIR}/scripts/debian-finish.sh"

 if [ "$SMSC95XX_MOREMEM" ];then
  sed -i 's/8192/16384/g' "${DIR}/scripts/ubuntu-tweaks.diff"
  sed -i 's/8192/16384/g' "${DIR}/scripts/debian-tweaks.diff"
 fi
}

function extract_base_initrd {
 echo "NetInstall: Extracting Base ${NETINSTALL}"
 cd ${TEMPDIR}/initrd-tree
 zcat "${DIR}/dl/${DISTARCH}/${NETINSTALL}" | cpio -i -d
 if [ ! "${DI_BROKEN_USE_CROSS}" ] ; then
  dpkg -x "${DIR}/dl/${DISTARCH}/${ACTUAL_DEB_FILE}" ${TEMPDIR}/initrd-tree
 else
  dpkg -x "${DIR}/dl/${DISTARCH}/${CROSS_DEB_FILE}" ${TEMPDIR}/initrd-tree
 fi
 cd "${DIR}/"
}

function initrd_add_firmware {
 echo "NetInstall: Adding Firmware"
case "$DIST" in
    maverick)
	dpkg -x "${DIR}/dl/${DISTARCH}/${MAVERICK_FW}" ${TEMPDIR}/initrd-tree
	dpkg -x "${DIR}/dl/${DISTARCH}/${MAVERICK_NONF_FW}" ${TEMPDIR}/initrd-tree
	cp -v "${DIR}/dl/${DISTARCH}/${AR9170_FW}" ${TEMPDIR}/initrd-tree/lib/firmware/
	cp -vr "${DIR}/dl/linux-firmware/ti-connectivity" ${TEMPDIR}/initrd-tree/lib/firmware/
        ;;
    natty)
	dpkg -x "${DIR}/dl/${DISTARCH}/${NATTY_FW}" ${TEMPDIR}/initrd-tree
	dpkg -x "${DIR}/dl/${DISTARCH}/${NATTY_NONF_FW}" ${TEMPDIR}/initrd-tree
	cp -v "${DIR}/dl/${DISTARCH}/${AR9170_FW}" ${TEMPDIR}/initrd-tree/lib/firmware/
	cp -vr "${DIR}/dl/linux-firmware/ti-connectivity" ${TEMPDIR}/initrd-tree/lib/firmware/
        ;;
    oneiric)
	dpkg -x ${DIR}/dl/${DISTARCH}/${ONEIRIC_FW} ${TEMPDIR}/initrd-tree
	dpkg -x ${DIR}/dl/${DISTARCH}/${ONEIRIC_NONF_FW} ${TEMPDIR}/initrd-tree
	cp -v ${DIR}/dl/${DISTARCH}/${AR9170_FW} ${TEMPDIR}/initrd-tree/lib/firmware/
	cp -vr ${DIR}/dl/linux-firmware/ti-connectivity ${TEMPDIR}/initrd-tree/lib/firmware/
        ;;
    precise)
	dpkg -x "${DIR}/dl/${DISTARCH}/${PRECISE_FW}" ${TEMPDIR}/initrd-tree
	dpkg -x "${DIR}/dl/${DISTARCH}/${PRECISE_NONF_FW}" ${TEMPDIR}/initrd-tree
	cp -v "${DIR}/dl/${DISTARCH}/${AR9170_FW}" ${TEMPDIR}/initrd-tree/lib/firmware/
	cp -vr "${DIR}/dl/linux-firmware/ti-connectivity" ${TEMPDIR}/initrd-tree/lib/firmware/
        ;;
    squeeze)
	#from: http://packages.debian.org/source/squeeze/firmware-nonfree
	dpkg -x "${DIR}/dl/${DISTARCH}/${ATMEL_FW}" ${TEMPDIR}/initrd-tree
	dpkg -x "${DIR}/dl/${DISTARCH}/${RALINK_FW}" ${TEMPDIR}/initrd-tree
	dpkg -x "${DIR}/dl/${DISTARCH}/${LIBERTAS_FW}" ${TEMPDIR}/initrd-tree
	dpkg -x "${DIR}/dl/${DISTARCH}/${ZD1211_FW}" ${TEMPDIR}/initrd-tree
	cp -v "${DIR}/dl/${DISTARCH}/${AR9170_FW}" ${TEMPDIR}/initrd-tree/lib/firmware/
	cp -vr "${DIR}/dl/linux-firmware/ti-connectivity" ${TEMPDIR}/initrd-tree/lib/firmware/
        ;;
esac
}

function initrd_cleanup {
 echo "NetInstall: Removing Optional Stuff to Save RAM Space"
 #Cleanup some of the extra space..
 rm -f ${TEMPDIR}/initrd-tree/boot/*-${KERNEL} || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/${KERNEL}/kernel/drivers/media/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/${KERNEL}/kernel/drivers/usb/serial/ || true

 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/${KERNEL}/kernel/drivers/net/bluetooth/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/${KERNEL}/kernel/drivers/net/irda/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/${KERNEL}/kernel/drivers/net/hamradio/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/${KERNEL}/kernel/drivers/net/can/ || true

 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/${KERNEL}/kernel/net/irda/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/${KERNEL}/kernel/net/decnet/ || true

 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/${KERNEL}/kernel/fs/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/${KERNEL}/kernel/sound/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/*-versatile/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/modules/*-omap || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/*-versatile/ || true

 #introduced with the big linux-firmware
 #http://packages.ubuntu.com/lucid/all/linux-firmware/filelist

 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/agere* || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/bnx2x-* || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/bcm700*fw.bin || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/dvb-* || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/ql2* || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/whiteheat* || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/v4l* || true

 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/3com/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/acenic/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/adaptec/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/advansys/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/asihpi/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/bnx2/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/cpia2/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/cxgb3/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/ea/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/emi26/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/emi62/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/ess/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/korg/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/keyspan/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/matrox/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/myricom/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/qlogic/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/r128/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/radeon/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/sb16/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/slicoss/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/sun/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/sxg/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/tehuti/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/tigon/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/ueagle-atm/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/vicam/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/yam/ || true
 rm -rf ${TEMPDIR}/initrd-tree/lib/firmware/yamaha/ || true
}

function initrd_preseed_settings {
 echo "NetInstall: Adding Distro Tweaks and Preseed Configuration"
 cd ${TEMPDIR}/initrd-tree/
 case "$DIST" in
     maverick)
         patch -p1 < "${DIR}/scripts/ubuntu-tweaks.diff"
         ;;
     natty)
         patch -p1 < "${DIR}/scripts/ubuntu-tweaks.diff"
         ;;
     oneiric)
         patch -p1 < "${DIR}/scripts/ubuntu-tweaks.diff"
         ;;
     precise)
         patch -p1 < "${DIR}/scripts/ubuntu-tweaks.diff"
         if [ "-${ARCH}-" = "-armhf-" ] ; then
          if [ ! -f ${TEMPDIR}/initrd-tree/lib/arm-linux-gnueabihf/ld-linux.so.3 ] ; then
           echo "NetInstall: fixing early ld-linux.so.3 location bug"
           mkdir -p ${TEMPDIR}/initrd-tree/lib/arm-linux-gnueabihf/
           cp -v ${TEMPDIR}/initrd-tree/lib/ld-linux.so.3 ${TEMPDIR}/initrd-tree/lib/arm-linux-gnueabihf/
          fi
         fi
         ;;
     squeeze)
         patch -p1 < "${DIR}/scripts/debian-tweaks.diff"
         ;;
     esac
 cd "${DIR}/"

case "$DIST" in
    maverick)
	 cp -v "${DIR}/scripts/flash-kernel.conf" ${TEMPDIR}/initrd-tree/etc/flash-kernel.conf
	 cp -v "${DIR}/scripts/serial.conf" ${TEMPDIR}/initrd-tree/etc/${SERIAL}.conf
	 chmod a+x ${TEMPDIR}/initrd-tree/usr/lib/finish-install.d/08rcn-omap
	 cp -v "${DIR}/scripts/${DIST}-preseed.cfg" ${TEMPDIR}/initrd-tree/preseed.cfg
	 cp -v "${DIR}/scripts/ubuntu-finish.sh" ${TEMPDIR}/initrd-tree/etc/finish-install.sh
        ;;
    natty)
	 cp -v "${DIR}/scripts/flash-kernel.conf" ${TEMPDIR}/initrd-tree/etc/flash-kernel.conf
	 cp -v "${DIR}/scripts/serial.conf" ${TEMPDIR}/initrd-tree/etc/${SERIAL}.conf
	 chmod a+x ${TEMPDIR}/initrd-tree/usr/lib/finish-install.d/08rcn-omap
	 cp -v "${DIR}/scripts/${DIST}-preseed.cfg" ${TEMPDIR}/initrd-tree/preseed.cfg
	 cp -v "${DIR}/scripts/ubuntu-finish.sh" ${TEMPDIR}/initrd-tree/etc/finish-install.sh
        ;;
    oneiric)
	 cp -v "${DIR}/scripts/flash-kernel.conf" ${TEMPDIR}/initrd-tree/etc/flash-kernel.conf
	 cp -v "${DIR}/scripts/serial.conf" ${TEMPDIR}/initrd-tree/etc/${SERIAL}.conf
	 chmod a+x ${TEMPDIR}/initrd-tree/usr/lib/finish-install.d/08rcn-omap
	 cp -v "${DIR}/scripts/${DIST}-preseed.cfg" ${TEMPDIR}/initrd-tree/preseed.cfg
	 cp -v "${DIR}/scripts/ubuntu-finish.sh" ${TEMPDIR}/initrd-tree/etc/finish-install.sh
        ;;
    precise)
	 cp -v "${DIR}/scripts/flash-kernel.conf" ${TEMPDIR}/initrd-tree/etc/flash-kernel.conf
	 cp -v "${DIR}/scripts/serial.conf" ${TEMPDIR}/initrd-tree/etc/${SERIAL}.conf
	 chmod a+x ${TEMPDIR}/initrd-tree/usr/lib/finish-install.d/08rcn-omap
	 cp -v "${DIR}/scripts/${DIST}-preseed.cfg" ${TEMPDIR}/initrd-tree/preseed.cfg
	 cp -v "${DIR}/scripts/ubuntu-finish.sh" ${TEMPDIR}/initrd-tree/etc/finish-install.sh
        ;;
    squeeze)
	 cp -v "${DIR}/scripts/e2fsck.conf" ${TEMPDIR}/initrd-tree/etc/e2fsck.conf
	 chmod a+x ${TEMPDIR}/initrd-tree/usr/lib/finish-install.d/08rcn-omap
	 cp -v "${DIR}/scripts/${DIST}-preseed.cfg" ${TEMPDIR}/initrd-tree/preseed.cfg
	 cp -v "${DIR}/scripts/debian-finish.sh" ${TEMPDIR}/initrd-tree/etc/finish-install.sh
        ;;
esac

if [ "$SERIAL_MODE" ];then
 #Squeeze: keymaps aren't an issue with serial mode so disable preseed workaround:
 sed -i -e 's:d-i console-tools:#d-i console-tools:g' ${TEMPDIR}/initrd-tree/preseed.cfg
 sed -i -e 's:d-i debian-installer:#d-i debian-installer:g' ${TEMPDIR}/initrd-tree/preseed.cfg
 sed -i -e 's:d-i console-keymaps-at:#d-i console-keymaps-at:g' ${TEMPDIR}/initrd-tree/preseed.cfg
fi
}

function initrd_fixes {
 echo "NetInstall: Adding Device Tweaks"
 touch ${TEMPDIR}/initrd-tree/etc/rcn.conf

 #work around for the kevent smsc95xx issue
 touch ${TEMPDIR}/initrd-tree/etc/sysctl.conf
 if [ "$SMSC95XX_MOREMEM" ];then
  echo "vm.min_free_kbytes = 16384" >> ${TEMPDIR}/initrd-tree/etc/sysctl.conf
 else
  echo "vm.min_free_kbytes = 8192" >> ${TEMPDIR}/initrd-tree/etc/sysctl.conf
 fi

 if [ "${SERIAL_MODE}" ] ; then
  if [ ! "${DD_UBOOT}" ] ; then
   #this needs more thought, need to disable the check for mx53loco, but maybe we don't need it for omap..
   touch ${TEMPDIR}/initrd-tree/etc/rcn-serial.conf
  fi
 fi
}

function recompress_initrd {
 echo "NetInstall: Compressing initrd image"
 cd ${TEMPDIR}/initrd-tree/
 find . | cpio -o -H newc | gzip -9 > ${TEMPDIR}/initrd.mod.gz
 cd "${DIR}/"
}

function extract_zimage {
 echo "NetInstall: Extracting Kernel Boot Image"
 if [ ! "${DI_BROKEN_USE_CROSS}" ] ; then
  dpkg -x "${DIR}/dl/${DISTARCH}/${ACTUAL_DEB_FILE}" ${TEMPDIR}/kernel
 else
  dpkg -x "${DIR}/dl/${DISTARCH}/${CROSS_DEB_FILE}" ${TEMPDIR}/kernel
 fi
}

function create_custom_netinstall_image {
 echo ""
 echo "NetInstall: Creating Custom Image"
 echo "-----------------------------"
 mkdir -p ${TEMPDIR}/kernel
 mkdir -p ${TEMPDIR}/initrd-tree

 extract_base_initrd

if [ "${FIRMWARE}" ] ; then
 mkdir -p ${TEMPDIR}/initrd-tree/lib/firmware/
 initrd_add_firmware
fi

 initrd_cleanup
 initrd_preseed_settings
 initrd_fixes
 recompress_initrd
 extract_zimage
}

function unmount_all_drive_partitions {
 echo ""
 echo "Unmounting Partitions"
 echo "-----------------------------"

 NUM_MOUNTS=$(mount | grep -v none | grep "$MMC" | wc -l)

 for (( c=1; c<=$NUM_MOUNTS; c++ ))
 do
  DRIVE=$(mount | grep -v none | grep "$MMC" | tail -1 | awk '{print $1}')
  umount ${DRIVE} &> /dev/null || true
 done

 parted --script ${MMC} mklabel msdos
}

function uboot_in_boot_partition {
 echo ""
 echo "Using fdisk to create BOOT Partition"
 echo "-----------------------------"
 echo "Debug: now using FDISK_FIRST_SECTOR over fdisk's depreciated method..."

 #With util-linux, 2.18+, the first sector is now 2048...
 FDISK_FIRST_SECTOR="1"
 if test $(fdisk -v | grep -o -E '2\.[0-9]+' | cut -d'.' -f2) -ge 18 ; then
  FDISK_FIRST_SECTOR="2048"
 fi

fdisk ${MMC} << END
n
p
1
${FDISK_FIRST_SECTOR}
+64M
t
e
p
w
END

 sync

 echo "Setting Boot Partition's Boot Flag"
 echo "-----------------------------"
 parted --script ${MMC} set 1 boot on

if [ "$FDISK_DEBUG" ];then
 echo "Debug: Partition 1 layout:"
 echo "-----------------------------"
 fdisk -l ${MMC}
 echo "-----------------------------"
fi
}

function dd_uboot_before_boot_partition {
 echo ""
 echo "Using dd to place bootloader before BOOT Partition"
 echo "-----------------------------"
 dd if=${TEMPDIR}/dl/${UBOOT} of=${MMC} seek=1 bs=1024

 #For now, lets default to fat16, but this could be ext2/3/4
 echo "Using parted to create BOOT Partition"
 echo "-----------------------------"
 parted --script ${PARTED_ALIGN} ${MMC} mkpart primary fat16 10 100
 #parted --script ${PARTED_ALIGN} ${MMC} mkpart primary ext3 10 100
}

function format_boot_partition {
 echo "Formating Boot Partition"
 echo "-----------------------------"
 mkfs.vfat -F 16 ${MMC}${PARTITION_PREFIX}1 -n ${BOOT_LABEL}
}

function create_partitions {

if [ "${DD_UBOOT}" ] ; then
 dd_uboot_before_boot_partition
else
 uboot_in_boot_partition
fi

 format_boot_partition
}

function populate_boot {
 echo "Populating Boot Partition"
 echo "-----------------------------"

 mkdir -p ${TEMPDIR}/disk

 if mount -t vfat ${MMC}${PARTITION_PREFIX}1 ${TEMPDIR}/disk; then

  mkdir -p ${TEMPDIR}/disk/cus
  mkdir -p ${TEMPDIR}/disk/debug
  if [ "${SPL_BOOT}" ] ; then
   if [ -f ${TEMPDIR}/dl/${MLO} ]; then
    cp -v ${TEMPDIR}/dl/${MLO} ${TEMPDIR}/disk/MLO
    cp -v ${TEMPDIR}/dl/${MLO} ${TEMPDIR}/disk/cus/MLO
   fi
  fi

  if [ ! "${DD_UBOOT}" ] ; then
   if [ -f ${TEMPDIR}/dl/${UBOOT} ]; then
    if echo ${UBOOT} | grep img > /dev/null 2>&1;then
     cp -v ${TEMPDIR}/dl/${UBOOT} ${TEMPDIR}/disk/u-boot.img
     cp -v ${TEMPDIR}/dl/${UBOOT} ${TEMPDIR}/disk/cus/u-boot.img
    else
     cp -v ${TEMPDIR}/dl/${UBOOT} ${TEMPDIR}/disk/u-boot.bin
     cp -v ${TEMPDIR}/dl/${UBOOT} ${TEMPDIR}/disk/cus/u-boot.bin
    fi
   fi
  fi

 VMLINUZ="vmlinuz-*"
 UIMAGE="uImage.net"

 if [ -f ${TEMPDIR}/kernel/boot/${VMLINUZ} ]; then
  LINUX_VER=$(ls ${TEMPDIR}/kernel/boot/${VMLINUZ} | awk -F'vmlinuz-' '{print $2}')
  echo "Using mkimage to create uImage"
  echo "-----------------------------"
  mkimage -A arm -O linux -T kernel -C none -a ${ZRELADD} -e ${ZRELADD} -n ${LINUX_VER} -d ${TEMPDIR}/kernel/boot/${VMLINUZ} ${TEMPDIR}/disk/${UIMAGE}
 fi

 INITRD="initrd.mod.gz"
 UINITRD="uInitrd.net"

 if [ -f ${TEMPDIR}/${INITRD} ]; then
  echo "Using mkimage to create uInitrd"
  echo "-----------------------------"
  mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n initramfs -d ${TEMPDIR}/${INITRD} ${TEMPDIR}/disk/${UINITRD}
 fi

if [ "${USE_UENV}" ] ; then
 echo "Copying uEnv.txt based boot scripts to Boot Partition"
 echo "-----------------------------"
 echo "Net Install Boot Script:"
 cp -v ${TEMPDIR}/bootscripts/netinstall.cmd ${TEMPDIR}/disk/uEnv.txt
 echo "-----------------------------"
 cat  ${TEMPDIR}/bootscripts/netinstall.cmd
 echo "-----------------------------"
 echo "Normal Boot Script:"
 cp -v ${TEMPDIR}/bootscripts/normal.cmd ${TEMPDIR}/disk/cus/normal.txt
 echo "-----------------------------"
 cat  ${TEMPDIR}/bootscripts/normal.cmd
 echo "-----------------------------"
 touch ${TEMPDIR}/disk/cus/use_uenv
else
 echo "Copying boot.scr based boot scripts to Boot Partition"
 echo "-----------------------------"
 echo "Net Install Boot Script:"
 cp -v ${TEMPDIR}/bootscripts/uEnv.cmd ${TEMPDIR}/disk/uEnv.txt
 cat ${TEMPDIR}/disk/uEnv.txt
 echo "-----------------------------"
 mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Debian Installer" -d ${TEMPDIR}/bootscripts/netinstall.cmd ${TEMPDIR}/disk/boot.scr
 cat ${TEMPDIR}/bootscripts/netinstall.cmd
 echo "-----------------------------"
 echo "Normal Boot Script:"
 cp -v ${TEMPDIR}/bootscripts/normal.cmd ${TEMPDIR}/disk/cus/boot.cmd
 cat  ${TEMPDIR}/bootscripts/normal.cmd
 echo "-----------------------------"
fi

cp -v "${DIR}/dl/${DISTARCH}/${ACTUAL_DEB_FILE}" ${TEMPDIR}/disk/

cat > ${TEMPDIR}/readme.txt <<script_readme

These can be run from anywhere, but just in case change to "cd /boot/uboot"

Tools:

 "./tools/update_boot_files.sh"

Updated with a custom uImage and modules or modified the boot.cmd/user.com files with new boot args? Run "./tools/update_boot_files.sh" to regenerate all boot files...

Applications:

 "./tools/minimal_xfce.sh"

Install minimal xfce shell, make sure to have network setup: "sudo ifconfig -a" then "sudo dhclient usb1" or "eth0/etc"

script_readme

cat > ${TEMPDIR}/update_boot_files.sh <<update_boot_files
#!/bin/sh

cd /boot/uboot
sudo mount -o remount,rw /boot/uboot

if [ ! -f /boot/initrd.img-\$(uname -r) ] ; then
sudo update-initramfs -c -k \$(uname -r)
else
sudo update-initramfs -u -k \$(uname -r)
fi

if [ -f /boot/initrd.img-\$(uname -r) ] ; then
sudo mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n initramfs -d /boot/initrd.img-\$(uname -r) /boot/uboot/uInitrd
fi

if [ -f /boot/uboot/boot.cmd ] ; then
sudo mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Boot Script" -d /boot/uboot/boot.cmd /boot/uboot/boot.scr
sudo cp /boot/uboot/boot.scr /boot/uboot/boot.ini
fi

if [ -f /boot/uboot/serial.cmd ] ; then
sudo mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Boot Script" -d /boot/uboot/serial.cmd /boot/uboot/boot.scr
fi

if [ -f /boot/uboot/user.cmd ] ; then
sudo mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "Reset Nand" -d /boot/uboot/user.cmd /boot/uboot/user.scr
fi

update_boot_files

cat > ${TEMPDIR}/minimal_xfce.sh <<basic_xfce
#!/bin/sh

sudo apt-get update
if lsb_release -c | grep -E 'oneiric|precise' ; then
sudo apt-get -y install xubuntu-desktop
else
sudo apt-get -y install xfce4 gdm xubuntu-gdm-theme xubuntu-artwork xserver-xorg-video-omap3 network-manager
fi

basic_xfce

 mkdir -p ${TEMPDIR}/disk/tools
 cp -v ${TEMPDIR}/readme.txt ${TEMPDIR}/disk/tools/readme.txt

 cp -v ${TEMPDIR}/update_boot_files.sh ${TEMPDIR}/disk/tools/update_boot_files.sh
 chmod +x ${TEMPDIR}/disk/tools/update_boot_files.sh

 cp -v ${TEMPDIR}/minimal_xfce.sh ${TEMPDIR}/disk/tools/minimal_xfce.sh
 chmod +x ${TEMPDIR}/disk/tools/minimal_xfce.sh

cd ${TEMPDIR}/disk
sync
cd "${DIR}/"

 echo "Debug: Contents of Boot Partition"
 echo "-----------------------------"
 ls -lh ${TEMPDIR}/disk/
 echo "-----------------------------"

umount ${TEMPDIR}/disk || true

 echo "Finished populating Boot Partition"
 echo "-----------------------------"
else
 echo "-----------------------------"
 echo "Unable to mount ${MMC}${PARTITION_PREFIX}1 at ${TEMPDIR}/disk to complete populating Boot Partition"
 echo "Please retry running the script, sometimes rebooting your system helps."
 echo "-----------------------------"
 exit
fi
 echo "mk_mmc.sh script complete"
}

function reset_scripts {

 #Setup serial
 sed -i -e 's:'$SERIAL':SERIAL:g' "${DIR}/scripts/serial.conf"
 sed -i -e 's:'$SERIAL':SERIAL:g' "${DIR}/scripts/ubuntu-tweaks.diff"
 sed -i -e 's:'$SERIAL':SERIAL:g' "${DIR}/scripts/debian-tweaks.diff"

 #Setup Kernel Boot Address
 sed -i -e 's:'$ZRELADD':ZRELADD:g' "${DIR}/scripts/ubuntu-tweaks.diff"
 sed -i -e 's:'$ZRELADD':ZRELADD:g' "${DIR}/scripts/debian-tweaks.diff"
 sed -i -e 's:'$ZRELADD':ZRELADD:g' "${DIR}/scripts/ubuntu-finish.sh"
 sed -i -e 's:'$ZRELADD':ZRELADD:g' "${DIR}/scripts/debian-finish.sh"

 if [ "$SMSC95XX_MOREMEM" ];then
  sed -i 's/16384/8192/g' "${DIR}/scripts/ubuntu-tweaks.diff"
  sed -i 's/16384/8192/g' "${DIR}/scripts/debian-tweaks.diff"
 fi

}

function check_mmc {

 FDISK=$(LC_ALL=C fdisk -l 2>/dev/null | grep "Disk ${MMC}" | awk '{print $2}')

 if test "-$FDISK-" = "-$MMC:-"
 then
  echo ""
  echo "I see..."
  echo "fdisk -l:"
  LC_ALL=C fdisk -l 2>/dev/null | grep "Disk /dev/" --color=never
  echo ""
  echo "mount:"
  mount | grep -v none | grep "/dev/" --color=never
  echo ""
  read -p "Are you 100% sure, on selecting [${MMC}] (y/n)? "
  [ "$REPLY" == "y" ] || exit
  echo ""
 else
  echo ""
  echo "Are you sure? I Don't see [${MMC}], here is what I do see..."
  echo ""
  echo "fdisk -l:"
  LC_ALL=C fdisk -l 2>/dev/null | grep "Disk /dev/" --color=never
  echo ""
  echo "mount:"
  mount | grep -v none | grep "/dev/" --color=never
  echo ""
  exit
 fi
}

function is_omap {
 IS_OMAP=1
 SPL_BOOT=1
 UIMAGE_ADDR="0x80300000"
 UINITRD_ADDR="0x81600000"
 SERIAL_CONSOLE="${SERIAL},115200n8"
 ZRELADD="0x80008000"
 SUBARCH="omap"
 VIDEO_CONSOLE="console=tty0"
 VIDEO_DRV="omapfb.mode=dvi"
 VIDEO_OMAP_RAM="12MB"
 VIDEO_OMAPFB_MODE="dvi"
 VIDEO_TIMING="1280x720MR-16@60"
}

function is_imx53 {
 IS_IMX=1
 UIMAGE_ADDR="0x70800000"
 UINITRD_ADDR="0x72100000"
 SERIAL_CONSOLE="${SERIAL},115200"
 ZRELADD="0x70008000"
 SUBARCH="imx"
 VIDEO_CONSOLE="console=tty0"
 VIDEO_FB="mxcdi1fb"
 VIDEO_TIMING="RGB24,1280x720M@60"
}

function check_uboot_type {
 unset DO_UBOOT

case "$UBOOT_TYPE" in
    beagle_bx)

 SYSTEM=beagle_bx
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 BOOTLOADER="BEAGLEBOARD_BX"
 SERIAL="ttyO2"
 USE_UENV=1
 is_omap
 echo "-----------------------------"
 echo "Warning: Support for the Original BeagleBoard Ax/Bx is broken.. (board locks up during hardware detect)"
 echo "Please use the Demo Images Instead"
 echo "-----------------------------"

        ;;
    beagle_cx)

 SYSTEM=beagle_cx
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 BOOTLOADER="BEAGLEBOARD_CX"
 SERIAL="ttyO2"
 USE_UENV=1
 is_omap
 echo "-----------------------------"
 echo "Warning: Support for the BeagleBoard C1/C2 is broken.. (board locks up during hardware detect)"
 echo "Please use the Demo Images Instead"
 echo "BeagleBoard: C4/C5 Users, can ignore this message.."
 echo "-----------------------------"

        ;;
    beagle_xm)

 SYSTEM=beagle_xm
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 BOOTLOADER="BEAGLEBOARD_XM"
 SERIAL="ttyO2"
 USE_UENV=1
 is_omap

        ;;
    bone)

 SYSTEM=bone
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 BOOTLOADER="BEAGLEBONE_A"
 SERIAL="ttyO0"
 USE_UENV=1
 is_omap
# mmc driver fails to load with this setting
# UIMAGE_ADDR="0x80200000"
# UINITRD_ADDR="0x80A00000"

 SERIAL_MODE=1
 SUBARCH="omap-psp"
        ;;
    igepv2)

 SYSTEM=igepv2
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 BOOTLOADER="IGEP00X0"
 SERIAL="ttyO2"
 is_omap

 SERIAL_MODE=1
        ;;
    panda)

 SYSTEM=panda
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 BOOTLOADER="PANDABOARD"
 SMSC95XX_MOREMEM=1
 SERIAL="ttyO2"
 USE_UENV=1
 is_omap
 VIDEO_OMAP_RAM="16MB"

        ;;
    panda_es)

 SYSTEM=panda_es
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 BOOTLOADER="PANDABOARD_ES"
 SMSC95XX_MOREMEM=1
 SERIAL="ttyO2"
 USE_UENV=1
 is_omap
 VIDEO_OMAP_RAM="16MB"

        ;;
    touchbook)

 SYSTEM=touchbook
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 BOOTLOADER="TOUCHBOOK"
 SERIAL="ttyO2"
 is_omap
 VIDEO_TIMING="1024x600MR-16@60"

 BETA_KERNEL=1
 SERIAL_MODE=1

        ;;
    crane)

 SYSTEM=crane
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 BOOTLOADER="CRANEBOARD"
 SERIAL="ttyO2"
 USE_UENV=1
 is_omap

 #with the crane, we need the beta kernel and serial-more
 BETA_KERNEL=1
 SERIAL_MODE=1

        ;;
    mx53loco)

 SYSTEM=mx53loco
 unset IN_VALID_UBOOT
 DO_UBOOT=1
 DD_UBOOT=1
 BOOTLOADER="MX53LOCO"
 SERIAL="ttymxc0"
 is_imx53

        ;;
	*)
		cat <<-__EOF__
			-----------------------------
			ERROR: This script does not currently recognize the selected: [--uboot ${UBOOT_TYPE}] option..
			Please rerun $(basename $0) with a valid [--uboot <device>] option from the list below:
			-----------------------------
			-Supported TI Devices:-------
			beagle_bx - <BeagleBoard Ax/Bx>
			beagle_cx - <BeagleBoard Cx>
			beagle_xm - <BeagleBoard xMA/B/C>
			bone - <BeagleBone Ax>
			igepv2 - <serial mode only>
			panda - <PandaBoard Ax>
			panda_es - <PandaBoard ES>
			-Supported Freescale Devices:
			mx53loco - <Quick Start Board>
			-----------------------------
		__EOF__
		exit
		;;
	esac
}

function check_distro {
 IN_VALID_DISTRO=1

 if test "-$DISTRO_TYPE-" = "-squeeze-"
 then
 DIST=squeeze
 ARCH=armel
 DISTARCH="${DIST}-${ARCH}"
 unset IN_VALID_DISTRO
 fi

 if test "-$DISTRO_TYPE-" = "-oneiric-"
 then
 DIST=oneiric
 ARCH=armel
 DISTARCH="${DIST}-${ARCH}"
 unset IN_VALID_DISTRO
 fi

 if test "-$DISTRO_TYPE-" = "-maverick-"
 then
 DIST=maverick
 ARCH=armel
 DISTARCH="${DIST}-${ARCH}"
 unset IN_VALID_DISTRO
 fi

 if test "-$DISTRO_TYPE-" = "-natty-"
 then
 DIST=natty
 ARCH=armel
 DISTARCH="${DIST}-${ARCH}"
 unset IN_VALID_DISTRO
 fi

 if test "-$DISTRO_TYPE-" = "-precise-armel-"
 then
 DIST=precise
 ARCH=armel
 DISTARCH="${DIST}-${ARCH}"
 unset IN_VALID_DISTRO
 fi

 if test "-$DISTRO_TYPE-" = "-precise-armhf-"
 then
 DIST=precise
 ARCH=armhf
 DISTARCH="${DIST}-${ARCH}"
 unset IN_VALID_DISTRO
 fi

 if [ "$IN_VALID_DISTRO" ] ; then
   usage
 fi
}

function usage {
    echo "usage: sudo $(basename $0) --mmc /dev/sdX --uboot <dev board>"
cat <<EOF

Script Version git: ${GIT_VERSION}
-----------------------------
Bugs email: "bugs at rcn-ee.com"

Required Options:
--mmc </dev/sdX>

--uboot <dev board>
    (omap)
    beagle_cx - <BeagleBoard C4/C5>
    beagle_xm - <BeagleBoard xMA/B/C>
    bone - <BeagleBone Ax>
    igepv2 - <serial mode only>
    panda - <PandaBoard Ax>
    panda_es - <PandaBoard ES>

    (freescale)
    mx53loco

Optional:
--distro <distro>
    Debian:
      squeeze <default>
    Ubuntu
      maverick (10.10 - End Of Life: April 2012)
      natty (11.04 - End Of Life: October 2012)
      oneiric (11.10 - End Of Life: April 2013)
      precise-armel (12.04)
      precise-armhf (12.04)

--addon <additional peripheral device>
    pico
    ulcd <beagle xm>

--firmware
    Add distro firmware

--serial-mode
    <force the Installer to use the serial port over the dvi/video outputs>

--svideo-ntsc
    force ntsc mode for svideo

--svideo-pal
    force pal mode for svideo

Additional Options:
-h --help
    this help

--probe-mmc
    List all partitions: sudo ./mk_mmc.sh --probe-mmc

Debug:
--earlyprintk
    <enables earlyprintk over serial>

EOF
exit
}

function checkparm {
    if [ "$(echo $1|grep ^'\-')" ];then
        echo "E: Need an argument"
        usage
    fi
}

IN_VALID_UBOOT=1

# parse commandline options
while [ ! -z "$1" ]; do
    case $1 in
        -h|--help)
            usage
            MMC=1
            ;;
        --probe-mmc)
            MMC="/dev/idontknow"
            check_root
            check_mmc
            ;;
        --mmc)
            checkparm $2
            MMC="$2"
	    if [[ "${MMC}" =~ "mmcblk" ]]
            then
	        PARTITION_PREFIX="p"
            fi
            find_issue
            check_mmc
            ;;
        --uboot)
            checkparm $2
            UBOOT_TYPE="$2"
            check_uboot_type
            ;;
        --distro)
            checkparm $2
            DISTRO_TYPE="$2"
            check_distro
            ;;
        --firmware)
            FIRMWARE=1
            ;;
        --serial-mode)
            SERIAL_MODE=1
            ;;
        --addon)
            checkparm $2
            ADDON=$2
            ;;
        --svideo-ntsc)
            SVIDEO_NTSC=1
            ;;
        --svideo-pal)
            SVIDEO_PAL=1
            ;;
        --deb-file)
            checkparm $2
            DEB_FILE="$2"
            KERNEL_DEB=1
            ;;
        --use-beta-kernel)
            BETA_KERNEL=1
            ;;
        --use-experimental-kernel)
            EXPERIMENTAL_KERNEL=1
            ;;
        --use-beta-bootloader)
            USE_BETA_BOOTLOADER=1
            ;;
        --earlyprintk)
            PRINTK=1
            ;;
    esac
    shift
done

if [ ! "${MMC}" ] ; then
	echo "ERROR: --mmc undefined"
	usage
fi

if [ "$IN_VALID_UBOOT" ] ; then
	echo "ERROR: --uboot undefined"
	usage
fi

if [ -n ${ADDON} ] ; then
	if ! is_valid_addon ${ADDON} ; then
		echo "ERROR: ${ADDON} is not a valid addon type"
		echo "-----------------------------"
		echo "Supported --addon options:"
		echo "    pico"
		echo "    ulcd <for the beagleboard xm>"
		exit
	fi
fi

 echo ""
 echo "Script Version git: ${GIT_VERSION}"
 echo "-----------------------------"

 find_issue
 detect_software
 dl_bootloader
 dl_kernel_image
 dl_netinstall_image

if [ "${FIRMWARE}" ] ; then
 dl_firmware
fi

 setup_bootscripts
 create_custom_netinstall_image

 unmount_all_drive_partitions
 create_partitions
 populate_boot
 reset_scripts

