Camera and hardware validation is manual.

Suggested checks:
1. Service status:
   sudo systemctl status nereus-agent --no-pager
   sudo systemctl status fieldcam --no-pager
2. Agent logs:
   sudo tail -f /var/log/nereus/agent.log
3. Camera capture behavior:
   verify images appear in /var/lib/nereus/images
4. GPS:
   watch for a real fix in telemetry/logs
5. Dashboard:
   verify the device reports and mode changes are received
6. Witty Pi:
   after configuration, verify wake/shutdown behavior on a real cycle
