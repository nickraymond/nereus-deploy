# External SD storage validation

Goal: verify the external media card can be detected, mounted, read, and written by the agent path.

The card does not need a specific label or name.

## 1. Show block devices

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,MODEL
```

Example for a 128 GB external card before mounting:

```text
sdb          117G                              MassStorageClass
`-sdb1       117G exfat
```

The Pi OS card should look like `mmcblk0`. Do not modify `mmcblk0`.

## 2. Run the agent external-media validation tool if present

```bash
cd /home/pi/code/nereus-vision-dev
source device/system_agent/.venv/bin/activate
if [[ -f device/tools/test_external_media_storage.py ]]; then
  python device/tools/test_external_media_storage.py
else
  echo "device/tools/test_external_media_storage.py not found in this branch"
fi
```

Expected:

- the tool identifies a usable external partition
- the tool mounts it, usually at `/mnt/nereus-media`
- the tool performs write/read/delete validation
- the tool reports success / storage OK

## 3. Confirm mounted result

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,MODEL
df -h /mnt/nereus-media 2>/dev/null || true
```

Expected example after successful mount:

```text
sdb          117G                              MassStorageClass
`-sdb1       117G exfat         /mnt/nereus-media
```

The exact label can be blank or any user-provided name.

## 4. Confirm agent env

```bash
sudo grep -Ei 'ENABLE_EXTERNAL_MEDIA_STORAGE|EXTERNAL_MEDIA_MOUNT_POINT|EXTERNAL_MEDIA_IMAGE_DIR|REQUIRE_EXTERNAL_MEDIA_ARCHIVE|ALLOW_TRANSIENT' /etc/nereus/nereus-agent.env
```

Expected:

```text
ENABLE_EXTERNAL_MEDIA_STORAGE=true
EXTERNAL_MEDIA_MOUNT_POINT=/mnt/nereus-media
EXTERNAL_MEDIA_IMAGE_DIR=/mnt/nereus-media/images
REQUIRE_EXTERNAL_MEDIA_ARCHIVE=false
ALLOW_TRANSIENT_CAPTURE_WITHOUT_EXTERNAL_MEDIA=true
```

Common failures:

- External device appears as `sdb` but no `sdb1`: partition is missing or unreadable.
- `FSTYPE` is blank: filesystem is missing or unsupported.
- exFAT mount fails: confirm `exfatprogs` is installed.
- Permission denied: check mount ownership/options.
- Do not modify `mmcblk0`; that is the Pi OS card.
