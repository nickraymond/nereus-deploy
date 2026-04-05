Finish Tailscale authentication in the browser.

1. The installer already ran:
   sudo tailscale up --hostname <name> --ssh

2. Open the login URL printed by Tailscale on your laptop.

3. Authenticate the device.

4. Verify:

   tailscale status
   tailscale ssh pi@<tailscale-hostname>

Return here after Tailscale authentication succeeds.
