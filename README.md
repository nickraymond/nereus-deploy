# nereus-deploy

Public bootstrap installer for Nereus Vision Raspberry Pi camera devices.

This repo is intentionally safe to keep public:
- no secrets
- no private SSH keys
- no backend tokens
- no customer credentials

It installs and configures:
- `nereus-agent` from the private `nereus-vision-dev` repo
- the required `fieldcam_app` field-service app
- optional Tailscale with SSH enabled by default
- current LiFePO4wered/Pi+ power-controller support
- legacy Witty Pi support for backwards-compatible devices
- BME280 / I2C Python dependencies used by the system agent

The default application branch is `staging` because the camera software is still in active development.

It also walks the user through manual steps that are still better done by a human:
- GitHub SSH setup for the private application repo
- Tailscale authentication
- LTE modem bring-up
- camera / hardware validation
- LiFePO4wered/Pi+ validation
- legacy Witty Pi configuration, if selected
- BME280 / I2C validation
- optional external SD validation
- optional wlan0 AP setup for field use

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

The installer will:
1. ask a few questions
2. ask which power-controller hardware is installed
3. run safe automated steps
4. clone/update `nereus-vision-dev` on the `staging` branch by default
5. create Python virtual environments
6. install `nereus-agent`, `fieldcam_app`, and BME280 dependencies
7. write service files and env files
8. pause for manual checkpoints when needed
9. start services if you approve

## Defaults

- API base: `https://nereus-vision-dev.onrender.com`
- Private app repo: `git@github.com:nickraymond/nereus-vision-dev.git`
- App branch: `staging`
- App install directory: `~/code/nereus-vision-dev`
- System agent: `device/system_agent`
- Field service app: `fieldcam_app`
- Agent env file: `/etc/nereus/nereus-agent.env`
- Local media cache: `/var/lib/nereus/images`
- Optional external media mount: `/mnt/nereus-media`

## Power controller choices

During install, choose one:

```text
lifepo4wered  Current LiFePO4wered/Pi+ path
wittypi       Legacy Witty Pi path
both          Install support for both hardware backends
none          No power controller support
```

The generated agent env uses:

```bash
ENABLE_POWER_CONTROLLER=true
POWER_CONTROLLER_BACKEND=auto
```

for LiFePO4wered/Pi+, Witty Pi, or both. Use `none` for always-on bench/dev systems.

## BME280 / I2C support

The installer installs the system packages needed for I2C and installs these Python packages into the `device/system_agent/.venv` environment:

```bash
adafruit-blinka
adafruit-circuitpython-bme280
```

It also attempts to enable I2C using `raspi-config nonint do_i2c 0` when that command is available.

## Update an existing deploy checkout

```bash
cd ~/nereus-deploy
git pull
chmod +x install.sh
./install.sh
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
- `manual_steps/` — human-in-the-loop instructions shown by the installer

## If you need to pull a clean new version of this repo

```bash
cd ~
mv nereus-deploy nereus-deploy-old
git clone https://github.com/nickraymond/nereus-deploy.git
```
