Tailscale authentication is manual.

The installer runs:
  sudo tailscale up --hostname <name> --ssh

If Tailscale prints a login URL:
1. Open it on your laptop
2. Authenticate the Pi
3. Verify:
   tailscale status

Expected:
- your Pi appears
- your laptop appears

Optional test:
  tailscale ssh pi@<tailscale-hostname>
