# Tailscale authentication

Tailscale authentication is manual.

The installer runs:

```bash
sudo tailscale up --hostname <name> --ssh
```

If Tailscale prints a login URL:

1. Open it on your laptop.
2. Authenticate the Pi.
3. Return to the Pi terminal.

The installer should only continue after authentication is complete. The Pi terminal should print `Success.` and `tailscale ip -4` should return a `100.x.x.x` address. Verify with:

```bash
tailscale status
tailscale ip -4
systemctl status tailscaled --no-pager
```

Expected:

- your Pi appears
- your laptop appears
- the Pi has a `100.x.x.x` Tailscale IP

If the installer stops because Tailscale is still `NeedsLogin` or `Logged out`, run `sudo tailscale up --ssh --hostname <name>` again. Once `tailscale ip -4` returns a `100.x.x.x` address, rerun the installer and resume the previous state:

```bash
cd ~/nereus-deploy
./install.sh
```

Optional test:

```bash
tailscale ssh pi@<tailscale-hostname>
```
