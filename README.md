# nereus-deploy

Public bootstrap repo for bringing up a Nereus Vision Pi.

## What it does

- guided, prompt-driven install
- state-aware resume after reboot
- installs the private `nereus-vision-dev` repo after a manual GitHub SSH checkpoint
- installs `nereus-agent`
- optionally installs `fieldcam_app`
- optionally installs Tailscale with SSH enabled
- installs Witty Pi last, then resumes at the post-reboot manual config step

## Typical flow

```bash
chmod +x install.sh
./install.sh
```

If the installer reaches the Witty Pi install step, it will ask you to reboot and then rerun:

```bash
./install.sh
```

It will resume from the saved state file instead of starting over.

## Notes

- Keep secrets out of this public repo.
- The default API base URL is set in `install.sh` and can be overridden at prompt time.
- Manual checkpoints are documented in `manual_steps/`.
