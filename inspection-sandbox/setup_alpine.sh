#!/bin/sh

# This script is executed inside the Alpine VM to perform an unattended installation.

set -eux

# --- Configuration ---
DISK="/dev/vda"
HOSTNAME="sandbox"

# --- Partitioning ---
apk add sfdisk
sfdisk "$DISK" << EOF
,1G,L
,,L
EOF

# --- Filesystem ---
mkfs.ext4 "${DISK}1"
mkfs.ext4 "${DISK}2"

# --- Mount ---
mount "${DISK}2" /mnt
mkdir /mnt/boot
mount "${DISK}1" /mnt/boot

# --- Setup ---
setup-disk -m sys /mnt

# --- System Configuration ---
echo "$HOSTNAME" > /mnt/etc/hostname

# --- SSH --- 
apk add openssh
rc-update add sshd

# --- SSH Keys ---
mkdir -p /mnt/root/.ssh
cat /media/shared/id_rsa.pub > /mnt/root/.ssh/authorized_keys
chmod 700 /mnt/root/.ssh
chmod 600 /mnt/root/.ssh/authorized_keys

# --- Unmount ---
umount -R /mnt

# --- Poweroff ---
poweroff
