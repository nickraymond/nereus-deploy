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

If authentication succeeds but the installer appears stuck at the login URL, press `Ctrl+C` once. Then verify:

```bash
tailscale status
tailscale ip -4
systemctl status tailscaled --no-pager
```

Expected:

- your Pi appears
- your laptop appears
- the Pi has a `100.x.x.x` Tailscale IP

If that looks good, rerun the installer and resume the previous state:

```bash
cd ~/nereus-deploy
./install.sh
```

Optional test:

```bash
tailscale ssh pi@<tailscale-hostname>
```
