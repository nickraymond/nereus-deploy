# nereus-deploy

Version: v4.7 LiFePO4wered-only power-controller patch

Public bootstrap installer for Nereus Vision Raspberry Pi camera devices.

This repo is intentionally safe to keep public: no secrets, no private SSH keys, no backend tokens, and no customer credentials.

## What it installs

- `nereus-agent` from the private `nereus-vision-dev` repo
- required `fieldcam_app` field-service app
- Tailscale with SSH support
- LTE/QMI user-space support: `ModemManager`, `libqmi-utils`, `usb-modeswitch`, `minicom`, `NetworkManager`
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

Trailing slashes are stripped from the API base before writing the env file.

## Power controller

Nereus field units now use **LiFePO4wered/Pi+ only**.

The installer writes:

```bash
ENABLE_POWER_CONTROLLER=true
```

Runtime code no longer has a fallback backend. If LiFePO4wered/Pi+ detection fails, the agent retries detection with exponential backoff and then fails loudly rather than selecting another controller.

## LTE/QMI note

On the Telit/Sixfab LTE path, the primary setup path is ModemManager + NetworkManager. You should not need AT commands when `/dev/cdc-wdm0` is present and `mmcli -L` sees the modem.

```text
cdc-wdm0 = modem control/QMI device managed by ModemManager/NetworkManager
wwan0    = network data interface that gets the IP and carries traffic
```

It is expected for `nmcli device status` to show `cdc-wdm0` as `gsm connected lte`, while `ip a show wwan0` shows the LTE IP address. Downstream telemetry should continue to treat `wwan0` as the data/uplink interface.

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

## Fresh-SD notes from v4.7

- Tailscale is a hard gate: the installer only continues after `tailscale ip -4` returns a `100.x.x.x` address.
- The installer creates `/var/tmp/nereus-transient` and sets it writable by `pi`.
- Prototype build setting: the installer enables `pi ALL=(ALL) NOPASSWD:ALL` in `/etc/sudoers.d/010-pi-nopasswd` because the agent uses noninteractive privileged commands for shutdown, modem/GPS, and dynamic storage mounting.
- Older narrow sudoers rules are removed because they are superseded by the prototype-wide rule.
- External SD validation must set `PYTHONPATH=/home/pi/code/nereus-vision-dev/device/system_agent/src` when running `device/tools/test_external_media_storage.py` from the repo root.
- BME280 reporting requires health monitoring on; the generated env sets `ENABLE_SYSTEM_HEALTH_MONITORING=true`.
- The power-controller runtime path is LiFePO4wered/Pi+ only.
