#!/bin/bash

CPU=`cat /proc/cpuinfo |grep processor | awk 'BEGIN {max = 0}{if($3>max) max=$3} END {print max}'` 
MAXCPU=$(((CPU + 1) *2))
re='[a-z][a-z][a-z][0-9][0-9][0-9][0-9]' #most UNIs regex

if [ $# -eq 0 ]
	then
	KERNVER=`head -3 Makefile |awk '{print $3}'|awk -vRS="" -vOFS='.' '$1=$1'`
	UNI=`cat .config | grep CONFIG_LOCALVERSION= | awk -F'"' '{print $2}'`
	echo "No kernel version or UNI given, using $KERNVER and $UNI"	
elif [ $# -eq 1 ]
	then
	if [[ $1 =~ $re ]]
		then
		KERNVER=`head -3 Makefile |awk '{print $3}'|awk -vRS="" -vOFS='.' '$1=$1'`
		UNI=-$1
		echo "using $KERNVER and $UNI"
	else
		UNI=`cat .config | grep CONFIG_LOCALVERSION= | awk -F'"' '{print $2}'`
		KERNVER=$1
		echo "using $KERNVER and $UNI"
	fi
else
	KERNVER=$1
	UNI=-$2
	echo "using $KERNVER and $UNI"
fi

function error_exit
{
	echo "$1" 1>&2
	exit 1
}

# first run make

if make -j$MAXCPU
	then echo "Make finished successfully"
else
	error_exit "Make failed"
fi

# make modules
if sudo make -j$MAXCPU modules_install
	then echo "make modules_install finished successfully"
else
	error_exit "make modules_install failed"
fi

# cp
if sudo cp -v arch/x86/boot/bzImage /boot/vmlinuz-$KERNVER$UNI
	then echo "cp success"
else
	error_exit "cp encountered an error"
fi

#mkinitcpio
if sudo mkinitcpio -k $KERNVER$UNI -c /etc/mkinitcpio.conf -g /boot/initramfs-$KERNVER$UNI.img
	then echo "mkinitcpio success"
else
	error_exit "mkinitcpio failure"
fi

# cp 
if sudo cp System.map /boot/System.map-$KERNVER$UNI
	then echo "cp success"
else
	error_exit "error copying System.map"
fi

# ln -sf
if sudo ln -sf /boot/System.map-$KERNVER$UNI /boot/System.map
	then echo "ln -sf success"
else
	error_exit "error making softlink to System.map"
fi

if [ -f /boot/vmlinuz-$KERNVER$UNI  ] && [ -f /boot/initramfs-$KERNVER$UNI.img ] && [ -f /boot/System.map-$KERNVER$UNI ] && [ -f /boot/System.map ]
	then echo "all files exist"
else
	error_exit "files are missing in /boot"
fi

#grub-mkconfig
if sudo grub-mkconfig -o /boot/grub/gru.cfg
	then echo "grub-mkconfig success"
else
	echo "grub-mkconfig error"
fi

VBOXVER=`pacman -Q virtualbox-guest-dkms |awk '{print $2}' |awk -F- '{print $1}'`

if sudo dkms remove vboxguest/$VBOXVER -k $KERNVER$UNI
	then echo "dkms removed ok"
else
	error_exit "dkms remove failed"
fi

if sudo dkms install vboxguest/$VBOXVER -k $KERNVER$UNI
	then echo "dkms installed ok"
else
	error_exit "dksm install failed"
fi

echo "********* MMK completed successfully ********"
exit