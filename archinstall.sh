#!/bin/bash/

clear

# Commands
getCPUArchitecture(){
    if ! grep --quiet 'Intel' /proc/cpuinfo; then
        CPU_UCODE=$"amd-ucode"
        return
    fi

    if grep --quiet 'Intel' /proc/cpuinfo; then
        CPU_UCODE=$"intel-ucode"
        return
    fi
}

createUser(){
    read -p "Please enter a username: " USERNAME

    while true; do
        read -p "Please enter a password: " USER_PASSWORD
        read -p "Confirm password: " USER_PASSWORD_CONFIRM
        if [ ${USER_PASSWORD} != ${USER_PASSWORD_CONFIRM} ]; then  
            echo "The passwords did not match up. Please try again."
            continue
        fi

        if [ ${USER_PASSWORD} == ${USER_PASSWORD_CONFIRM} ]; then
            echo "Root password set."
            break
        fi

        done
}

rootPassword(){
    while true; do
        read -p "Please enter a root password. Do NOT forget this. " ROOT_PASSWORD
        read -p "Confirm password: " ROOT_PASSWORD_CONFIRM
        if [ ${ROOT_PASSWORD} != ${ROOT_PASSWORD_CONFIRM} ]; then
            echo "The passwords did not match up. Please try again."
            continue
        fi

        if [ ${ROOT_PASSWORD} == ${ROOT_PASSWORD_CONFIRM} ]; then
            echo "Root password set."
            break
        fi

        done

}

## Desktop
desktopEnvironment(){
    echo "Choose a desktop environment."
    echo "1) KDE Plasma - Standard desktop experience, recommended if new to Linux. Note: Will also install Konsole."
    echo "2) Gnome - If you've used Ubuntu, this is similar to that. Another recommended DE if you're new. Note: Will also install Gnome Terminal."
    echo "3) Hyprland - Extremely customisable, however, is also quite difficult. Not recommended unless you know what you're doing. Note: Will also install kitty."
    echo "4) i3 - Similar to Hyprland, however, I recommend this *less* than Hyprland. Note: Will also install xterm."
    read -p "Please choose one (i.e., 1 for KDE): " DESKTOP_CHOICE
    case $DESKTOP_CHOICE in
        1 ) DESKTOP_ENVIRONMENT="plasma-desktop konsole"
            return 0;;

        2 ) DESKTOP_ENVIRONMENT="gnome gnome-terminal"
            return 0;;

        3 ) DESKTOP_ENVIRONMENT="hyprland kitty"
            return 0;;

        4 ) DESKTOP_ENVIRONMENT="i3-wm xterm"
            return 0;;

        * ) echo "You did not select a valid environment, please try again."
            return 1

    esac
}

desktopEnviromentExt(){
    if [[ ${DESKTOP_CHOICE} == "plasma-desktop konsole" ]]; then
        read -p "Would you like to install extra packages? This will take longer, and will take up more storage. [y/n] " EXTRA_PACKAGES
        if [[ ${EXTRA_PACKAGES} == "y" ]]; then
            echo "Extra packages will be installed."
            DESKTOP_CHOICE="${DESKTOP_CHOICE} kde-applications-meta"

        else
            echo "Extra packages will not be installed. You can install these later."
        fi
    fi

    if [[ ${DESKTOP_CHOICE} == "gnome gnome-terminal" ]]; then
        read -p "Would you like to install extra packages? This will take longer, and will take up more storage. [y/n] " EXTRA_PACKAGES
        if [[ ${EXTRA_PACKAGES} == "y" ]]; then
            echo "Extra packages will be installed."
            DESKTOP_CHOICE="${DESKTOP_CHOICE} gnome-extra"

        else
            echo "Extra packages will not be installed. You can install these later."
        fi
    fi

    if [[ ${DESKTOP_CHOICE} == "hyprland kitty" ]]; then
        read -p "Would you like to install Hyprpaper, Hyprlock and Wofi? This may take longer and will take up more storage. [y/n] " EXTRA_PACKAGES
        if [[ ${EXTRA_PACKAGES} == "y" ]]; then
            echo "Hyprpaper, Hyprlock and Wofi will be installed. Note: You will need to configure these for yourself."
            DESKTOP_CHOICE="${DESKTOP_CHOICE} hyprpaper wofi hyprlock"

        else   
            echo "Extra packages will not be installed. You can install these later."
        fi
    fi
}

## User details
getUserDetails(){
    read -p "Please choose a hostname for this computer. " HOSTNAME
    if [[ -z ${HOSTNAME} ]]; then
        HOSTNAME="IUseArchBTW"
    fi

    read -p "Please enter locale, or, leave blank for en_US.UTF-8 UTF-8. " LOCALE
    if [[ -z ${LOCALE} ]]; then
        LOCALE="en_US.UTF-8 UTF-8"
    fi
}
## Partition
formatDisk(){
    read -p "Please select a disk to install this to. If you are unsure, please run lsblk outside of this script. " DISK
    echo "WARNING! THIS WILL ERASE ALL DATA ON ${DISK}!"
    read -p "Do you wish to continue? [y/n] " WARNING_CONFIRMATION

    if [[ ${WARNING_CONFIRMATION} == "n" ]]; then
        echo "Understood."
        exit 0
    fi

    EFI_BOOT_PARTITION=$"${DISK}1"
    SWAP_PARTITION=$"${DISK}2"
    ROOT_PARTITION=$"${DISK}3"

    sgdisk -og ${DISK}

    # Boot partition
    sgdisk -n 1:2048:+512MB -t 1:ef00 ${DISK}

    # Swap partition
    sgdisk -n 2:0:+4G -t 2:8200 ${DISK}

    # Root partition
    sgdisk -n 3:0:0 -t 3:8300 ${DISK}

    echo "${DISK} has been successfully wiped. Formatting disks now..."

    # Formatting
    mkfs.ext4 ${ROOT_PARTITION}
    echo "Root partition has been formatted."

    mkfs.fat -F 32 ${EFI_BOOT_PARTITION}
    echo "Boot partition has been formatted."

    mkswap ${SWAP_PARTITION}
    echo "Swap partition has been formatted. All partitions are now formatted. Mounting drives now."

    # Mount drives
    mount ${ROOT_PARTITION} /mnt
    mount --mkdir ${EFI_BOOT_PARTITION} /mnt/boot/efi
    swapon ${SWAP_PARTITION}

    echo "All partitions are now mounted."
}

# Install process.

echo -e "GET http://google.com HTTP/1.0\n\n" | nc google.com 80 > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Online. Install process wil begin."
else
    echo "Offline. Install process cannot begin. Please connect to internet, and run this again."
    exit 0
fi

until createUser; do : ; done
until getUserDetails; do : ; done
until getCPUArchitecture; do : ; done

until desktopEnvironment; do : ; done
until desktopEnviromentExt; do : ; done

until formatDisk; do : ; done

mkdir /mnt/etc/fstab
genfstab -U /mnt >> /mnt/etc/fstab

pacstrap -K /mnt linux linux-firmware sof-firmware base base-devel networkmanager sddm nano man-db firefox grub efibootmgr ${CPU_UCODE} ${DESKTOP_ENVIRONMENT}

sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen
echo "LANG=$locale" > /mnt/etc/locale.conf
echo "$HOSTNAME" >> /mnt/etc/hostname


arch-chroot /mnt /bin/bash -e <<EOF
    # Timezone
    ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime &>/dev/null

    # Clock sync
    hwclock --systohc

    # Locale-gen
    locale-gen &>/dev/null

    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

EOF

systemctl enable NetworkManager
systemctl enable sddm
echo "Be sure to run the 'nmtui' command once you have logged in if you have wifi."

until rootPassword; do : ; done

echo ${ROOT_PASSWORD} | arch-chroot /mnt chpasswd 
echo "If this fails, arch-chroot into the system and run passwd to set it manually."

if [[ -n "$username" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    echo "Adding the user $username to the system with root privilege."
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
    echo "Setting user password for $username."
    echo "$username:$userpass" | arch-chroot /mnt chpasswd
fi
