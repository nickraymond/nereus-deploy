# nereus-deploy

Version: v4.9 production installer hardening + LTE identity inventory

Public bootstrap installer for Nereus Vision Raspberry Pi camera devices.

This repo is intentionally safe to keep public: no secrets, no private SSH keys, no backend tokens, and no customer credentials.

## What it installs

- `nereus-agent` from the private `nereus-vision-dev` repo
- required `fieldcam_app` field-service app
- Tailscale with SSH support
- LTE/QMI user-space support: `ModemManager`, `libqmi-utils`, `usb-modeswitch`, `minicom`, `NetworkManager`
- LTE identity inventory capture: modem IMEI and SIM ICCID
- LiFePO4wered/Pi+ power-controller support
- BME280 / I2C dependencies
- external-media support tools for exFAT/FAT32 cards
- optional automated `wlan0` FieldCam access point

The default application branch is `staging` because the camera software is still in active development.

## Quick start

```bash
sudo apt update
sudo apt install -y git
cd ~
git clone https://github.com/nickraymond/nereus-deploy.git
cd nereus-deploy
chmod +x install.sh
./install.sh
```

## Important defaults

- API base default: `https://nereus-vision-dev.onrender.com`
- Private app repo: `git@github.com:nickraymond/nereus-vision-dev.git`
- App branch: `staging`
- App install directory: `~/code/nereus-vision-dev`
- Agent env file: `/etc/nereus/nereus-agent.env`
- Per-system cloud config cache: `/var/lib/nereus/system_config_cache_<SYSTEM_ID>.json`
- Local media cache: `/var/lib/nereus/images`
- External media mount: `/mnt/nereus-media`
- Health log dir: `/var/log/nereus/health`
- Field AP SSID: `NEREUS <SYSTEM_ID>`
- Device identity inventory file: `/etc/nereus/device_identity.json`

Trailing slashes are stripped from the API base before writing the env file.

## Power controller

Nereus field units now use **LiFePO4wered/Pi+ only**.

The installer writes:

```bash
ENABLE_POWER_CONTROLLER=true
POWER_CONTROLLER_BACKEND=lifepo4wered
POWER_SCHEDULE_STATE_PATH=/var/lib/nereus/last_power_schedule.json
ENABLE_LIFEPO4WERED_PREARM_WAKE=true
LIFEPO4WERED_PREARM_WAKE_SEC=600
```

Runtime code no longer has a fallback backend. If LiFePO4wered/Pi+ detection fails, the agent retries detection with exponential backoff and then fails loudly rather than selecting another controller.

## LTE/QMI note

On the Telit/Sixfab LTE path, the primary setup path is ModemManager + NetworkManager. You should not need AT commands when `/dev/cdc-wdm0` is present and `mmcli -L` sees the modem.

```text
cdc-wdm0 = modem control/QMI device managed by ModemManager/NetworkManager
wwan0    = network data interface that gets the IP and carries traffic
```

It is expected for `nmcli device status` to show `cdc-wdm0` as `gsm connected lte`, while `ip a show wwan0` shows the LTE IP address. Downstream telemetry should continue to treat `wwan0` as the data/uplink interface.

## Production-run hardening in v4.9

The installer now fails early on the issues that caused bring-up risk during the first field units:

- Tailscale authentication is a hard gate. The installer stops unless `tailscale ip -4` returns a `100.x.x.x` address.
- LiFePO4wered/Pi+ is a hard gate. The installer verifies `I2C_REG_VER`, `RTC_TIME`, `RTC_WAKE_TIME` write/read, and `AUTO_BOOT=0`.
- Runtime/cache/fallback directories are created and read/write/delete tested before the agent starts:
  - `/var/log/nereus`
  - `/var/log/nereus/health`
  - `/var/lib/nereus`
  - `/var/lib/nereus/cache`
  - `/var/lib/nereus/offline`
  - `/var/lib/nereus/images`
  - `/var/tmp/nereus-transient`
  - `/mnt/nereus-media/images` when external media is mounted
- LTE data path is tested end-to-end over `wwan0` with ping and API curl.
- GPS raw/NMEA is enabled and checked, but a GPS fix is not required during installation.
- Active runtime code is scanned for old Witty Pi runtime references.

## LTE identity inventory

During bring-up, the installer reads from ModemManager:

```bash
mmcli -m <modem_id> --output-keyvalue
mmcli -i <sim_id> --output-keyvalue
```

It captures:

- modem IMEI
- SIM ICCID
- cellular operator ID/name when available

The installer writes these to:

```bash
/etc/nereus/device_identity.json
```

and also writes the values into `/etc/nereus/nereus-agent.env` as admin-only inventory fields:

```bash
MODEM_IMEI=...
SIM_ICCID=...
CELLULAR_OPERATOR_ID=...
CELLULAR_OPERATOR_NAME=...
DEVICE_IDENTITY_PATH=/etc/nereus/device_identity.json
```

Treat IMEI and ICCID as admin-only inventory values. Do not expose them in public/customer UI endpoints.

## Update an existing deploy checkout

```bash
cd ~/nereus-deploy
git fetch origin
git reset --hard origin/main
git clean -fd
chmod +x install.sh
./install.sh
```

If previous installer state is stale during development, clear it:

```bash
rm -rf ~/.nereus-deploy
```

## Update the camera application on a Pi

```bash
cd ~/code/nereus-vision-dev
git fetch origin
git checkout staging
git pull origin staging
sudo systemctl restart nereus-agent
sudo systemctl restart fieldcam
```

## Files

- `install.sh` — guided installer
- `templates/` — systemd and env templates
- `manual_steps/` — human-in-the-loop validation steps shown by the installer
- `tools/watch_agent_logs.py` — optional Windows helper for streaming `/var/log/nereus/agent.log` over Tailscale SSH

## Fresh-SD notes from v4.9

- Tailscale is a hard gate: the installer only continues after `tailscale ip -4` returns a `100.x.x.x` address.
- The installer creates `/var/tmp/nereus-transient` and sets it writable by `pi`.
- Prototype build setting: the installer enables `pi ALL=(ALL) NOPASSWD:ALL` in `/etc/sudoers.d/010-pi-nopasswd` because the agent uses noninteractive privileged commands for shutdown, modem/GPS, and dynamic storage mounting.
- Older narrow sudoers rules are removed because they are superseded by the prototype-wide rule.
- External SD validation must set `PYTHONPATH=/home/pi/code/nereus-vision-dev/device/system_agent/src` when running `device/tools/test_external_media_storage.py` from the repo root.
- BME280 reporting requires health monitoring on; the generated env sets `ENABLE_SYSTEM_HEALTH_MONITORING=true`.
- The power-controller runtime path is LiFePO4wered/Pi+ only.


## Production-run checklist additions

Before building multiple units, verify the installer summary shows a non-unknown IMEI/ICCID when a SIM/modem is present. If either value is `unknown`, run:

```bash
mmcli -L
mmcli -m 0
mmcli -i 0
sudo cat /etc/nereus/device_identity.json
```

