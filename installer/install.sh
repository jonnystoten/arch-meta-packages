#!/bin/bash

set -euo pipefail
IFS=$'\n\t'
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

REPO_URL="https://jonnystoten-arch.ams3.digitaloceanspaces.com/repo/x86_64/"

hostname=$(dialog --stdout --inputbox "Choose a hostname for this machine" 0 0) || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

username=$(dialog --stdout --inputbox "Choose a name for the admin user" 0 0) || exit 1
clear
: ${username:?"username cannot be empty"}

password=$(dialog --stdout --passwordbox "Choose a password for the admin user (and root)" 0 0) || exit 1
clear
: ${password:?"password cannot be empty"}
password2=$(dialog --stdout --passwordbox "Enter the password again" 0 0) || exit 1
clear
[[ "$password" == "$password2" ]] || ( echo "Passwords didn't match"; exit 1 )

partition_choices=(
  "manually"
  "Do everything manually, and mount under /mnt"
  "auto"
  "Set up regular partition scheme, and format with ext4"
  "auto (encrypted)"
  "Same as auto, but also encrypt with LUKS"
)

partition_choice=$(dialog --stdout --menu "How do you want to do partitions?" 0 0 0 ${partition_choices[@]}) || exit 1
clear

#timedatectl set-ntp true

case $partition_choice in
  manually)
    echo "OK, dropping you into a bash shell to sort out the partitions"
    echo "When you've finished, please mount everything under /mnt"

    bash --init-file <(echo "export PS1='[partitions] # '")

    echo Welcome back
    ;;
  auto*)
    OLD_IFS=$IFS
    IFS=$' \t\n'
    devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
    device=$(dialog --stdout --menu "Select installtion disk" 0 0 0 $devicelist) || exit 1
    IFS=$OLD_IFS
    clear
    echo "Oops, this isn't implemented yet!"
    exit 1
    ;;
esac

exec 1> >(tee stdout.log)
exec 2> >(tee stderr.log)

cat >> /etc/pacman.conf <<EOF
[jonnystoten]
SigLevel = Optional TrustAll
Server = $REPO_URL
EOF

pacstrap /mnt jonnystoten-base intel-ucode
genfstab -t PARTUUID /mnt >> /mnt/etc/fstab
echo "$hostname" > /mnt/etc/hostname

cat >> /mnt/etc/pacman.conf <<EOF
[jonnystoten]
SigLevel = Optional TrustAll
Server = $REPO_URL
EOF

arch-chroot /mnt bootctl install

cat > /mnt/boot/loader/loader.conf <<EOF
default arch
EOF

part_root=$(df -P / | tail -1 | awk '{print $1}')

cat > /mnt/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value "$part_root") rw
EOF

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime

cat > /mnt/etc/locale.gen <<EOF
en_US.UTF-8 UTF-8
en_GB.UTF-8 UTF-8
EOF

arch-chroot /mnt locale-gen

echo "LANG=en_GB.UTF-8" > /mnt/etc/locale.conf

arch-chroot /mnt useradd -mU -s /usr/bin/fish -G wheel "$user"
# TODO is this a good idea?
arch-chroot /mnt chsh -s /usr/bin/fish

echo "$user:$password" | chpasswd --root /mnt
echo "root:$password" | chpasswd --root /mnt
