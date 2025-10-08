#!/bin/sh
# -----------------------------------------------------------------------------
#
# Script Name: setup_alpine.sh
#
# Description: This script is executed INSIDE the Alpine Linux VM to perform
#              an unattended installation. It partitions the disk, creates
#              filesystems, installs the base system, configures the hostname,
#              and sets up SSH access by copying a public key from the
#              shared directory.
#
# Usage: This script is typically run automatically or manually from within
#        the Alpine installation environment.
#
# WARNING: This script is destructive and will format the specified disk.
#
# Author: Gemini
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit on error and print commands.
set -eux

# --- Configuration ---
DISK="/dev/vda"
HOSTNAME="sandbox"
SHARED_DIR="/media/shared"

# --- Main Execution ---
start_time=$(date +%s)

echo "--- Starting Unattended Alpine Installation ---"

# 1. Partition the disk
echo "Partitioning disk: $DISK"
apk add --no-cache sfdisk
sfdisk "$DISK" << EOF
,1G,L,*
,,L
EOF

# 2. Create filesystems
echo "Creating ext4 filesystems..."
mkfs.ext4 "${DISK}1"
mkfs.ext4 "${DISK}2"

# 3. Mount filesystems
echo "Mounting filesystems..."
mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

# 4. Install the base system
echo "Running setup-disk to install the system..."
setup-disk -m sys /mnt

# 5. Configure the system
echo "Configuring hostname to '$HOSTNAME'..."
echo "$HOSTNAME" > /mnt/etc/hostname

# 6. Set up SSH access
echo "Configuring SSH..."
# Install SSH if not already present in the chroot
apk add --no-cache -p /mnt openssh
# Add SSH service to default runlevel
chroot /mnt /sbin/rc-update add sshd default

# Copy the public key from the shared folder
if [ -f "${SHARED_DIR}/id_rsa.pub" ]; then
    echo "Copying SSH public key..."
    mkdir -p /mnt/root/.ssh
    cp "${SHARED_DIR}/id_rsa.pub" /mnt/root/.ssh/authorized_keys
    chmod 700 /mnt/root/.ssh
    chmod 600 /mnt/root/.ssh/authorized_keys
else
    echo "WARNING: SSH public key not found at ${SHARED_DIR}/id_rsa.pub"
fi

# 7. Unmount and finish
echo "Unmounting filesystems..."
umount -R /mnt

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo "--- Alpine Installation Complete ---"
echo "Total execution time: ${execution_time} seconds."
echo "System will now power off."

# 8. Power off
poweroff