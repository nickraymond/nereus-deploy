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
