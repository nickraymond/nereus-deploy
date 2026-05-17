# External SD validation

Use this checkpoint if the camera has the external USB SD storage installed.

## 1. Confirm the block device and mount

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,MODEL
```

Expected pattern:

```text
sdb1  vfat  NEREUS  /mnt/nereus-media
```

The exact device name can change, so prefer labels or UUIDs for persistent mounts.

## 2. Confirm the mount is writable

```bash
touch /mnt/nereus-media/.nereus_write_test
ls -lah /mnt/nereus-media/.nereus_write_test
rm /mnt/nereus-media/.nereus_write_test
```

## 3. Confirm agent env

```bash
sudo grep -E 'EXTERNAL_MEDIA_MOUNT|REQUIRE_EXTERNAL_MEDIA_STORAGE|LOCAL_IMAGE_DIR' /etc/nereus/nereus-agent.env
```

Default values:

```bash
EXTERNAL_MEDIA_MOUNT=/mnt/nereus-media
REQUIRE_EXTERNAL_MEDIA_STORAGE=false
LOCAL_IMAGE_DIR=/var/lib/nereus/images
```

## 4. Notes

For field use, FAT32/vfat is convenient because it is readable by Windows and macOS. If the card is removed while not writing, the agent should detect the missing mount and fall back according to config. Avoid removing it during a write.
