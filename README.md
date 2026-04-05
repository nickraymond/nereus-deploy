# nereus-deploy

Public bootstrap installer for Nereus Vision Raspberry Pi devices.

This repo is intentionally safe to keep public:
- no secrets
- no private SSH keys
- no backend tokens
- no customer credentials

It installs and configures:
- `nereus-agent` from the private `nereus-vision-dev` repo
- `fieldcam_app`
- optional Tailscale with SSH enabled by default
- optional Witty Pi software installed last, with resume after reboot

It also walks the user through the manual steps that are still better done by a human:
- GitHub SSH setup
- Witty Pi interactive configuration
- LTE modem bring-up
- camera / hardware validation
- optional wlan0 AP setup for field use

## Quick start

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/YOUR-ORG/nereus-deploy.git
cd nereus-deploy
chmod +x install.sh
./install.sh
```

The installer will:
1. ask a few questions
2. run safe automated steps
3. pause for manual checkpoints when needed
4. write service files and env files
5. start the services if you approve
6. install Witty Pi last so the reboot happens at the end
7. resume from saved state after reboot

If the installer reaches the Witty Pi install step, it will ask you to reboot and then rerun:

```bash
./install.sh
```

It will resume from the saved state file instead of starting over.

## Notes

- Default API base is `https://nereus-vision-dev.onrender.com`
- Tailscale defaults to `--ssh`
- `fieldcam_app` is installed by default
- the private repo clone still requires manual GitHub SSH setup first
- manual checkpoints are documented in `manual_steps/`

## Files

- `install.sh` — guided installer
- `templates/` — service and env templates
- `manual_steps/` — human-in-the-loop instructions shown by the installer

## If you need to pull a clean new version of this repo

```bash
cd ~
mv nereus-deploy nereus-deploy-old
git clone https://github.com/nickraymond/nereus-deploy.git
```
