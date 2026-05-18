# nereus-deploy

Version: v4.5 fresh-SD reliability patch

Public bootstrap installer for Nereus Vision Raspberry Pi camera devices.

This repo is intentionally safe to keep public: no secrets, no private SSH keys, no backend tokens, and no customer credentials.

## What it installs

- `nereus-agent` from the private `nereus-vision-dev` repo
- required `fieldcam_app` field-service app
- Tailscale with SSH support
- LTE/QMI user-space support: `ModemManager`, `libqmi-utils`, `usb-modeswitch`, `minicom`, `NetworkManager`
- noninteractive `mmcli` sudo rule for the agent GPS/LTE path
- LiFePO4wered/Pi+ power-controller support
- optional legacy Witty Pi support
- BME280 / I2C dependencies
- external-media support tools for exFAT/FAT32 cards
- optional automated `wlan0` FieldCam access point

The default application branch is `staging` because the camera software is still in active development. v4.5 keeps the normal LTE bring-up on the ModemManager/NetworkManager path; AT commands are debug-only.

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

## Power controller choices

During install, choose one:

```text
lifepo4wered  Current LiFePO4wered/Pi+ path
wittypi       Legacy Witty Pi path
both          Install support for both hardware backends
none          No power controller support
```

For LiFePO4wered/Pi+, the generated env uses:

```bash
ENABLE_POWER_CONTROLLER=true
POWER_CONTROLLER_BACKEND=auto
ENABLE_WITTYPI=false
```

The LiFePO4wered/Pi+ manual validation step includes setting `AUTO_BOOT=1` for unattended solar/battery recovery.

## LTE/QMI note

On the Telit/Sixfab LTE path, the primary setup path is ModemManager + NetworkManager. You should not need AT commands when `/dev/cdc-wdm0` is present and `mmcli -L` sees the modem.



```text
cdc-wdm0 = modem control/QMI device managed by ModemManager/NetworkManager
wwan0    = network data interface that gets the IP and carries traffic
```

It is expected for `nmcli device status` to show `cdc-wdm0` as `gsm connected lte`, while `ip a show wwan0` shows the LTE IP address. Downstream telemetry should continue to treat `wwan0` as the data/uplink interface. Seeing `cdc-wdm0 gsm disconnected` before profile activation is normal; creating/bringing up the `lte` profile starts the data session.

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

## Fresh-SD notes from v4.5

- Tailscale is now a hard gate: the installer only continues after `tailscale ip -4` returns a `100.x.x.x` address. If browser auth does not end with `Success.`, rerun `sudo tailscale up --ssh --hostname=<name>` and then resume the installer.
- The installer creates `/var/tmp/nereus-transient`, sets it writable by `pi`, and installs scoped storage sudoers rules for dynamic external-media mounting.
- External SD validation must set `PYTHONPATH=/home/pi/code/nereus-vision-dev/device/system_agent/src` when running `device/tools/test_external_media_storage.py` from the repo root.
- BME280 reporting requires health monitoring on; the generated env sets `ENABLE_SYSTEM_HEALTH_MONITORING=true`.
