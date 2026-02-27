#!/usr/bin/env bash
#
# Kali Linux ARM build-script for Mecha Comet (arm64) - SINGLE PARTITION VERSION
#

set -e

# Workaround for mmdebstrap issues in some Docker environments
export FORCE_DEBOOTSTRAP=1

# Hardware model
hw_model=${hw_model:-"mecha-comet"}
architecture=${architecture:-"arm64"}
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
status_stage3 'Set up locales'
locale-gen en_US.UTF-8 || true
update-locale LANG=en_US.UTF-8 || true

status_stage3 'Download and install custom Mecha kernel'
wget -q "${kernel_url}" -O /tmp/kernel.deb
eatmydata dpkg -i /tmp/kernel.deb
rm /tmp/kernel.deb

status_stage3 'Copy DTBs to /boot'
# We keep everything on the same partition, so /boot is just a directory
mkdir -p /boot/freescale
cp /usr/lib/linux-image-6.12.20+mecha+/freescale/*.dtb /boot/freescale/
cp /usr/lib/linux-image-6.12.20+mecha+/freescale/*.dtb /boot/

status_stage3 'Update initramfs'
update-initramfs -u -k 6.12.20+mecha+
EOF

# Run third stage
include third_stage

# Clean system
include clean_system

# --- BEGIN SINGLE-PARTITION IMAGE CREATION (Userspace only) ---
status "Starting Single-Partition Image Creation"

# Generate FSTAB with a single entry
root_uuid="44444444-4444-4444-8888-888888888888"

cat <<EOF >"${work_dir}"/etc/fstab
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
proc            /proc           proc    defaults          0       0
UUID=$root_uuid /               ext4    errors=remount-ro 0       1
EOF

# Create the filesystem image
status "Creating raw rootfs image using mkfs.ext4 -d"
# Calculate size needed (rootfs + free space)
root_size_kb=$(du -sk "${work_dir}" | cut -f1)
total_root_kb=$((root_size_kb + (free_space * 1024) + 102400)) # 100MB buffer
truncate -s "${total_root_kb}K" "${base_dir}/rootfs.img"
mkfs.ext4 -L ROOTFS -U "$root_uuid" -d "${work_dir}" "${base_dir}/rootfs.img"

# Assemble as a disk image with a partition table (optional but recommended for .img)
status "Assembling final disk image: ${image_name}.img"
image_file="${image_dir}/${image_name}.img"
mkdir -p "${image_dir}"

# 1MiB offset for the first partition (classic MBR offset)
offset_mib=1
full_size_mib=$((offset_mib + (total_root_kb / 1024) + 2))
truncate -s "${full_size_mib}M" "${image_file}"

# Create MBR Partition Table with one partition
parted -s "${image_file}" mklabel msdos
parted -s "${image_file}" mkpart primary ext4 "${offset_mib}MiB" 100%

# Write the rootfs into the partition
status "Writing rootfs into the disk image"
dd if="${base_dir}/rootfs.img" of="${image_file}" bs=1M seek="${offset_mib}" conv=notrunc
sync

# Finalize
status "Image creation complete. Compressing..."
cd "${image_dir}"
shasum -a 256 "${image_name}.img" > "${image_name}.img.sha256sum"

if [ "${compress}" = "xz" ]; then
    status "Compressing file: ${image_name}.img"
    xz -T0 "${image_name}.img"
    shasum -a 256 "${image_name}.img.xz" > "${image_name}.img.xz.sha256sum"
    img_final="${image_dir}/${image_name}.img.xz"
else
    img_final="${image_dir}/${image_name}.img"
fi

cd "${repo_dir}"
log "Done! Your image is: ${img_final}" bold
total_time $SECONDS
exit 0
