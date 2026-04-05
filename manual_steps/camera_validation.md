Run these checks in another terminal/session.

1. Verify nereus-agent:

   sudo systemctl status nereus-agent --no-pager
   sudo tail -f /var/log/nereus/agent.log

2. Verify fieldcam if installed:

   sudo systemctl status fieldcam --no-pager
   journalctl -u fieldcam -n 100 --no-pager

3. Confirm image directory is writable:

   ls -lah /var/lib/nereus/images

4. Confirm the backend already knows this SYSTEM_ID and DEVICE_ID and the dashboard is reachable.

5. Run a short capture test and confirm:
   - one image is created
   - upload succeeds
   - cycle log appears if enabled
   - Witty Pi scheduling succeeds if enabled

6. If GPS/LTE are present, confirm:
   - modem signal metrics appear
   - GPS eventually returns a fix

Return here after your first hardware sanity check.
