#!/usr/bin/env bash
# Prepares the k3s machine's NAS disk (scsi1, created by terraform/cluster): an ext4 file
# system labelled "nas", mounted at /mnt/nas, in fstab. Safe to run again: it never formats
# a disk that already has a file system, and skips what is already in place.
#
# Not in cloud-init on purpose: cloud-init runs once, and changing its template recreates the
# machine. Run this after `just cluster apply` creates the machine or its NAS disk.
#
#   nas-disk.sh <user@host>
set -euo pipefail

TARGET="${1:?missing user@host}"

ssh "$TARGET" sudo bash -s <<'REMOTE'
set -euo pipefail
DEVICE=/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1
MOUNT=/mnt/nas

[ -b "$DEVICE" ] || { echo "no NAS disk at $DEVICE — is scsi1 attached (just cluster apply)?" >&2; exit 1; }

if [ -z "$(blkid -o value -s TYPE "$DEVICE" || true)" ]; then
    echo "formatting $DEVICE as ext4 (label nas)"
    mkfs.ext4 -q -L nas "$DEVICE"
else
    echo "file system present on $DEVICE — not formatting"
fi

mkdir -p "$MOUNT"
# nofail: without the NAS the machine still boots; only what uses /mnt/nas fails.
LINE="LABEL=nas $MOUNT ext4 defaults,nofail,x-systemd.device-timeout=30s 0 2"
grep -q "^LABEL=nas " /etc/fstab || { echo "$LINE" >> /etc/fstab; systemctl daemon-reload; }
mountpoint -q "$MOUNT" || mount "$MOUNT"
df -h "$MOUNT"
REMOTE
