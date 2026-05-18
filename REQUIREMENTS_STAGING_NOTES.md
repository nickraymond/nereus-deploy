# Staging branch requirements notes

These notes describe the private `nereus-vision-dev` staging requirements that the public deploy repo now assumes.

## `device/system_agent/requirements.txt`

The BME280 read path should be owned by the private app repo long-term:

```text
adafruit-blinka
adafruit-circuitpython-bme280
```

The deploy installer also installs these into the system-agent venv as a safety net.

## OS packages installed by deploy

```text
git
curl
jq
python3
python3-venv
python3-pip
i2c-tools
build-essential
libsystemd-dev
rpicam-apps
python3-picamera2
network-manager
modemmanager
libqmi-utils
usb-modeswitch
minicom
exfatprogs
dosfstools
rfkill
```

## Runtime env naming

Current staging env should use:

```bash
ENABLE_POWER_CONTROLLER=true
POWER_CONTROLLER_BACKEND=auto
ENABLE_SYSTEM_HEALTH_MONITORING=true
ENABLE_BME280_INTERNAL_ENV=true
ENABLE_EXTERNAL_MEDIA_STORAGE=true
EXTERNAL_MEDIA_MOUNT_POINT=/mnt/nereus-media
REQUIRE_EXTERNAL_MEDIA_ARCHIVE=false
ALLOW_TRANSIENT_CAPTURE_WITHOUT_EXTERNAL_MEDIA=true
```

Do not use stale keys in new deploy templates:

```bash
EXTERNAL_MEDIA_MOUNT
REQUIRE_EXTERNAL_MEDIA_STORAGE
SYSTEM_CONFIG_CACHE_PATH=/var/lib/nereus/system_config_cache.json
```

Use a per-system config cache path instead:

```bash
SYSTEM_CONFIG_CACHE_PATH=/var/lib/nereus/system_config_cache_${SYSTEM_ID}.json
```


## v4.4 validation updates

- LTE primary path is ModemManager + NetworkManager; AT commands are troubleshooting only.
- It is normal for `cdc-wdm0` to show `gsm disconnected` before the `lte` profile is activated.
- External SD validation from repo root requires:

```bash
PYTHONPATH=/home/pi/code/nereus-vision-dev/device/system_agent/src \
python device/tools/test_external_media_storage.py
```

- If Tailscale auth hangs after browser authentication, verify `tailscale status`, then rerun the installer and resume.


## v4.6 installer polish

- Tailscale authentication is a hard gate: install should not continue unless `tailscale ip -4` returns a `100.x.x.x` address.
- Installer creates `/var/tmp/nereus-transient`, assigns it to `pi:pi`, and sets mode `775` so transient fallback capture can write images.
- Installer now uses one prototype-wide sudoers rule: `pi ALL=(ALL) NOPASSWD:ALL`. This prevents hidden noninteractive sudo failures in shutdown/poweroff, mmcli/GPS, modem, and dynamic external-media paths.
- Installer removes obsolete narrow sudoers rules: `/etc/sudoers.d/nereus-mmcli`, `/etc/sudoers.d/nereus-storage`, and `/etc/sudoers.d/nereus-power`.
