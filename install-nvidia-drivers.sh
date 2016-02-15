#!/bin/bash

set -e

# This script was made expecting RHEL/Centos 7 

# expect install at location: /usr/src/nvidia.run
# if not we will try to download it

# check for root permissions
if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

check_for_nvidia_graphics_card()
{
    card_exists=`lspci | grep -i --color vga | grep NVIDIA`
    if [ -n "$card_exists" ]; then
        echo "Found NVIDIA card" # do nothing
    else
        exit 1
    fi
}

get_nvidia_installer()
{
    # check for installer relative first
    # then check on the machine
    # if not on machine try to download it
    if [ -f "/usr/src/nvidia.run" ]; then
        echo "Already have nvidia installer on system"
    elif [ -f "$DIR/nvidia.run" ]; then
        cp $DIR/nvidia.run /usr/src/nvidia.run
    elif [ ! -f "/usr/src/nvidia.run" ]; then
       wget -O /usr/src/nvidia.run http://us.download.nvidia.com/XFree86/Linux-x86_64/358.16/NVIDIA-Linux-x86_64-358.16.run
    fi
    chmod +x /usr/src/nvidia.run
}

get_package_dependencies()
{
    yum -y update
    yum -y --nogpgcheck install kernel-devel kernel-headers glibc-devel gcc make
}

update_kernel_version()
{
    yum -y upgrade kernel kernel-devel
}

create_initd_file()
{
    cat > /etc/init.d/$1 << EOF
#! /bin/sh

### BEGIN INIT INFO
# Provides:          $1
# chkconfig: 345 99 01
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin

case "\$1" in
    start)
        $DIR/install-nvidia-drivers.sh
        ;;
    stop|restart|reload)
        ;;
esac
EOF
chmod +x /etc/init.d/$1
}

disable_graphical_interface()
{
    rm -f /etc/systemd/system/default.target 
    ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
}

patch_nouveau()
{
    # remove the nouveau drivers to prevent a conflict
    rpm -e xorg-x11-drivers xorg-x11-drv-nouveau

    # make sure a file exists
    touch /etc/modprobe.d/blacklist.conf

    # blacklist nouveau
    if grep -q "nouveau" /etc/modprobe.d/blacklist.conf
    then
        echo "" # do nothing
    else
        echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
    fi
}

patch_grub()
{
    # there are 2 types of settings 1 for EFI and 1 for BIOS, not sure how to handle this
    # @TODO put some logic in here to handle this
    # @TODO Assuming bios and centos for now
    
    # For BIOS
    grub2-mkconfig -o /boot/grub2/grub.cfg

    # For EFI
    #grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg

    # For EFI RHEL
    #grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
}

install_nvidia_driver()
{
    /usr/src/nvidia.run --silent --tmpdir /root/
}

enable_graphical_interface()
{
    rm -f /etc/systemd/system/default.target
    ln -fs /lib/systemd/system/graphical.target /etc/systemd/system/default.target
}

install_auto_graphics_kernel()
{
    cp $DIR/init_files/gfx /etc/init.d/
    chmod +x /etc/init.d/gfx
    chkconfig --add gfx
}

phase1()
{
    check_for_nvidia_graphics_card
    get_package_dependencies
    get_nvidia_installer
    update_kernel_version
}

phase2()
{
    disable_graphical_interface
}

phase3()
{
    patch_nouveau
    patch_grub
}

phase4()
{
    install_nvidia_driver
    enable_graphical_interface
    install_auto_graphics_kernel
}

# first thing to do
mkdir -p /opt/run
if [ -f /opt/run/phase2 ]; then
    phase2
    rm /opt/run/phase2
    chkconfig --del phase2
    # get ready for phase 3
    create_initd_file "phase3"
    touch /opt/run/phase3
    chkconfig --add phase3
    reboot
elif [ -f /opt/run/phase3 ]; then
    phase3
    rm /opt/run/phase3
    chkconfig --del phase3
    # get ready for phase4
    create_initd_file "phase4"
    touch /opt/run/phase4
    chkconfig --add phase4
    reboot
elif [ -f /opt/run/phase4 ]; then
    phase4
    rm /opt/run/phase4
    chkconfig --del phase4
    # we are done
    reboot
else #this is the first case
    phase1
    create_initd_file "phase2"
    touch /opt/run/phase2
    chkconfig --add phase2
    reboot
fi

