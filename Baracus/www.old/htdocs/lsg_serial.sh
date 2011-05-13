#!/bin/bash

########## GET CONSOLE FROM /proc/cmdline ###################
get_ttyS()
{
    local x

    TTYSX=ttyS0
    x="$(cat /proc/cmdline |sed 's/.*console=\(ttyS[0-9]\).*/\1/')"
    if [ -e /dev/"$x" ];then
        TTYSX=$x
    fi
}

########## ENABLING SYSREQ #############################
enable_sysreq()
{
    echo "ENABLING SYSREQ"

    echo -n "Enabling sysreq ... "
    grep ENABLE_SYSRQ=\"yes\" /etc/sysconfig/sysctl >/dev/null
    if [ $? -eq 0 ];then
        echo "sysreq already enabled."
    else
        sed -i -e 's/ENABLE_SYSRQ="no"/ENABLE_SYSRQ="yes"/g' /etc/sysconfig/sysctl
    fi
    grep ENABLE_SYSRQ=\"yes\" /etc/sysconfig/sysctl >/dev/null
    if [ $? -eq 0 ];then
        echo "sysreq enabled."
    else
        echo "sysreq could not be enabled"
    fi
    if [ -w /proc/sys/kernel/sysrq ];then
        echo 1 > /proc/sys/kernel/sysrq
        echo "Sysreq activated"
    else
        echo "Sysreq could not be activated - /proc not mounted?"
    fi
}

########## MODIFING /etc/inittab
enable_stty0()
{
    echo
    echo "MODIFING /etc/inittab AND /etc/securetty"

    if [ -w /etc/inittab ];then
    ### INITDEFAULT
        grep "id:3:initdefault:" /etc/inittab >/dev/null
        if [ $? -eq 0 ];then
            echo "Runlevel 3 already activated"
        else
            sed -i -e 's/id:5:initdefault:/id:3:initdefault:/g' /etc/inittab
            grep "id:3:initdefault:" /etc/inittab >/dev/null
            if [ $? -eq 0 ];then
                echo "Runlevel 3 activated"
            else
                echo "Runlevel 3 could not be activated"
            fi
        fi
    ### ENABLE AGETTY ON TTYSX
        grep "#S0:12345:respawn:/sbin/agetty -L 9600 ttyS0 vt102" /etc/inittab >/dev/null
        if [ $? -eq 0 ];then
            sed -i -e 's/#S0:12345:respawn:\/sbin\/agetty -L 9600 ttyS0 vt102/S0:12345:respawn:\/sbin\/agetty -L 57600 '$TTYSX' vt102/g' /etc/inittab
            grep "^S0.*57600 $TTYSX" /etc/inittab >/dev/null
            if [ $? = 0 ];then
                echo "Serial console log in enabled at 57600 baudrate"
            else
                echo "Could not enable serial log in"
            fi
        else
            echo "agetty string already modified in /etc/inittab - skipping"
        fi
    ### Workaround for bad inittab entry -> comment it out:
        grep "cons:[[:digit:]]*:respawn:/sbin/smart_agetty -L 42 console" /etc/inittab >/dev/null
        if [ $? -eq 0 ];then
            sed -i -e 's/cons:\([[:digit:]]*\):respawn:\/sbin\/smart_agetty -L 42 console/#cons:\1:respawn:\/sbin\/smart_agetty -L 42 console/g' /etc/inittab
            echo "Corrected bogus inittab entry"
        else
            echo "Bogus inittab entry not found"
        fi

    else
        echo "Cannot write /etc/inittab"
    fi
}

####### MODIFY /etc/securetty #########
add_serial_secure_tty()
{
    if [ -w /etc/securetty ];then
        grep "$TTYSX" /etc/securetty >/dev/null
        if [ $? -eq 0 ];then
            echo "Secure $TTYSX already set in /etc/securetty"
        else
            echo $TTYSX >> /etc/securetty
        fi
    else
        echo "Cannot write /etc/securetty"
    fi
}

############ MODIFING /boot/grub/menu.lst - BE CAREFUL, BETTER ADD A PARAMETER ######
modify_grub_menu_list()
{
    if ! [ -w /boot/grub/menu.lst ]; then
        echo "Cannot write /boot/grub/menu.lst"
        return
    fi

    echo "# Old menu.lst saved by lsg_serial.sh" >> /boot/grub/menu.lst.old_setup
    echo "#" >> /boot/grub/menu.lst.old_setup
    cat /boot/grub/menu.lst >> /boot/grub/menu.lst.old_setup

    ### Disable white/blue background
    grep "^color white/blue black/light-gray" /boot/grub/menu.lst >/dev/null
    if [ $? -eq 0 ];then
        sed -i -e 's/color white\/blue black\/light-gray/#color white\/blue black\/light-gray/g' /boot/grub/menu.lst
        grep "^#color white/blue black/light-gray" /boot/grub/menu.lst >/dev/null
        if [ $? = 0 ];then
            echo "White/blue background disabled in /boot/grub/menu.lst"
        else
            echo "White/blue background could not be disabled in /boot/grub/menu.lst"
        fi
    fi

    ### set the serial command after timeout X
    grep "serial.*--unit.*--speed" /boot/grub/menu.lst >/dev/null
    if [ $? -eq 0 ];then
        echo "Serial console already set up in /boot/grub/menu.lst"
    else
        tmp=`grep timeout /boot/grub/menu.lst`
        sed -i -e 's/'"$tmp"'/'"$tmp"'\n\nserial --unit=0 --speed=57600\nterminal --timeout=10 serial console\n/g' /boot/grub/menu.lst
        grep "serial.*--unit.*--speed" /boot/grub/menu.lst >/dev/null
        if [ $? -eq 0 ];then
            echo "Serial console successfully set to baudrate 57600 in /boot/grub/menu.lst"
        else
            echo "Could not set up serial console configuration in /boot/grub/menu.lst"
        fi
    fi

    ### set the serial console for each kernel
    grep "console=$TTYSX" /boot/grub/menu.lst >/dev/null
    if [ $? -eq 0 ];then
        echo "Serial kernel console already set up in /boot/grub/menu.lst"
    else
        sed -i -e 's/\(vmlinuz\S*\s\)/\1 console=tty0 console='$TTYSX',57600 /g' /boot/grub/menu.lst
        grep "console=$TTYSX" /boot/grub/menu.lst >/dev/null
        if [ $? -eq 0 ];then
            echo "Serial kernel console successfully set to baudrate 57600 in /boot/grub/menu.lst"
        else
            echo "Could not set up kernel serial console configuration in /boot/grub/menu.lst"
        fi
    fi

    ### Disable gfx graphical grub menu
    grep "^gfxmenu.*" /boot/grub/menu.lst >/dev/null
    if [ $? -eq 0 ];then
        sed -i -e 's/gfxmenu\(.*\)/#gfxmenu\1/g' /boot/grub/menu.lst
        grep "^gfxmenu" /boot/grub/menu.lst >/dev/null
        if [ $? -eq 0 ];then
            echo "Could not disable graphical gfx grub menu in /boot/grub/menu.lst"
        else
            echo "Graphical gfx grub menu in /boot/grub/menu.lst disabled"
        fi
    else
        echo "No graphical gfx grub menu configuration in /boot/grub/menu.lst found - disabling not needed"
    fi

    ### Remove vga= options
    VGA_COUNT=`grep -c "vga=" /boot/grub/menu.lst`
    if [ $VGA_COUNT -gt 0 ];then
        sed -i -e 's/vga=[0-9x]\+//g' /boot/grub/menu.lst
        VGA_COUNT_AFTER=`grep -c "vga=" /boot/grub/menu.lst`
        VGA_COUNT_DIFF=$(($VGA_COUNT - $VGA_COUNT_AFTER))
        if [ $VGA_COUNT_AFTER -eq 0 ];then
            echo "Deleted $VGA_COUNT_AFTER vga= options in /boot/grub/menu.lst - no vga= options left"
        else
            echo "Could not delete all vga= options, still $VGA_COUNT_DIFF options left:"
            echo -n "/boot/grub/menu.lst - line: "; grep -n "vga=" /boot/grub/menu.lst
        fi
    else
        echo "No vga= options found in /boot/grub/menu.lst"
    fi

    ### Remove splash options
    SPLASH_COUNT=`grep -c "splash=[[:alnum:]]*" /boot/grub/menu.lst`
    if [ $SPLASH_COUNT -gt 0 ];then
        sed -i -e 's/splash=[[:alnum:]]*//g' /boot/grub/menu.lst
        SPLASH_COUNT_AFTER=`grep -c "splash=" /boot/grub/menu.lst`
        SPLASH_COUNT_DIFF=$(($SPLASH_COUNT - $SPLASH_COUNT_AFTER))
        if [ $SPLASH_COUNT_AFTER -eq 0 ];then
            echo "Deleted $SPLASH_COUNT_AFTER splash= options in /boot/grub/menu.lst - no splash= options left"
        else
            echo "Could not delete all splash= options, still $SPLASH_COUNT_DIFF options left:"
            echo -n "/boot/grub/menu.lst - line: "; grep -n "splash=" /boot/grub/menu.lst
        fi
    fi
}

get_ttyS
enable_sysreq
enable_stty0
add_serial_secure_tty
modify_grub_menu_list

# :tabSize=8:shiftWidth=4:noTabs=true:maxLineLen=0:
