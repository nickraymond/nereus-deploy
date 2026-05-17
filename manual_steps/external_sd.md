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

Run from the repo root and set `PYTHONPATH` so the tool can import the `system_agent` package:

```bash
cd /home/pi/code/nereus-vision-dev
source device/system_agent/.venv/bin/activate

if [[ -f device/tools/test_external_media_storage.py ]]; then
  PYTHONPATH=/home/pi/code/nereus-vision-dev/device/system_agent/src   python device/tools/test_external_media_storage.py
else
  echo "device/tools/test_external_media_storage.py not found in this branch"
fi
```

Expected success example:

```text
[storage] external media mounted partition=/dev/sdb1 fstype=exfat label=NEREUS mount_point=/mnt/nereus-media
[storage] external media ready image_dir=/mnt/nereus-media/images
MEDIA_STORAGE_PLAN
  archive_available: true
  archive_mode: external_sd
  image_dir: /mnt/nereus-media/images
WRITE_TEST path=/mnt/nereus-media/images/week13_write_test.txt bytes=3
MEDIA_STORAGE_STATUS
  storage_ok: true
  storage_full: false
  storage_corrupt: false
```

A blank or different label is okay. The validation uses the agent storage logic, not a fixed card label.

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

- `ModuleNotFoundError: No module named system_agent`: rerun with the `PYTHONPATH=.../device/system_agent/src` prefix shown above.
- External device appears as `sdb` but no `sdb1`: partition is missing or unreadable.
- `FSTYPE` is blank: filesystem is missing or unsupported.
- exFAT mount fails: confirm `exfatprogs` is installed.
- Permission denied: check mount ownership/options.
- Do not modify `mmcblk0`; that is the Pi OS card.
