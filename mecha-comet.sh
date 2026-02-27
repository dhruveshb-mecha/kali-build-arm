#!/usr/bin/env bash
#
# Kali Linux ARM build-script for Mecha Comet (arm64)
#

set -e

# Hardware model
hw_model=${hw_model:-"mecha-comet"}

# Architecture
architecture=${architecture:-"arm64"}

# Desktop manager (xfce, gnome, i3, kde, lxde, mate, e17 or none)
desktop=${desktop:-"xfce"}

# Load default base_image configs
source ./common.d/base_image.sh

# Network configs
basic_network
add_interface eth0

# Kernel URL
kernel_url="https://pub-a2f44c787cec4290833312e57fd59522.r2.dev/linux-image-6.12.20%2Bmecha%2B_6.12.20-gb769de07f921-1_arm64.deb"

# Third stage enhancements
cat <<EOF >> "${work_dir}"/third-stage
status_stage3 'Download and install custom Mecha kernel'
wget -q "${kernel_url}" -O /tmp/kernel.deb
eatmydata dpkg -i /tmp/kernel.deb
rm /tmp/kernel.deb

status_stage3 'Copy DTBs to /boot'
# The package installed DTBs to /usr/lib/linux-image-6.12.20+mecha+/freescale/
# We copy them to /boot so U-Boot can find them according to standard patterns
mkdir -p /boot/freescale
cp /usr/lib/linux-image-6.12.20+mecha+/freescale/*.dtb /boot/freescale/
# Also copy to /boot directly if U-Boot expects them there
cp /usr/lib/linux-image-6.12.20+mecha+/freescale/*.dtb /boot/

# Ensure initramfs is updated for the new kernel
status_stage3 'Update initramfs'
update-initramfs -u -k 6.12.20+mecha+
EOF

# Run third stage
include third_stage

# Clean system
include clean_system

# Calculate the space to create the image and create
make_image

# Create the disk partitions
status "Create the disk partitions"
# Using msdos partition table
parted -s "${image_dir}/${image_name}.img" mklabel msdos
parted -s "${image_dir}/${image_name}.img" mkpart primary fat32 1MiB "${bootsize}"MiB
parted -s -a minimal "${image_dir}/${image_name}.img" mkpart primary "$fstype" "${bootsize}"MiB 100%

# Set the partition variables
make_loop

# Create file systems
mkfs_partitions

# Make fstab
make_fstab

# Create the dirs for the partitions and mount them
status "Create the dirs for the partitions and mount them"
mkdir -p "${base_dir}"/root/
mount "${rootp}" "${base_dir}"/root
mkdir -p "${base_dir}"/root/boot
mount "${bootp}" "${base_dir}"/root/boot

status "Rsyncing rootfs into image file"
rsync -HPavz -q --exclude boot "${work_dir}"/ "${base_dir}"/root/
rsync -rtx -q "${work_dir}"/boot/ "${base_dir}"/root/boot/
sync

# Final cleanup and completion
include finish_image
