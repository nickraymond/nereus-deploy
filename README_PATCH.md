# nereus-deploy production installer hardening v4.9 + IMEI/ICCID

This patch refreshes the v4.8 production installer hardening work and adds LTE identity inventory capture during bring-up.

## Full replacement files

- `install.sh`
- `README.md`
- `templates/nereus-agent.env.template`

## Main changes

- LiFePO4wered/Pi+ hard gate:
  - verifies `I2C_REG_VER`
  - verifies `RTC_TIME`
  - tests `RTC_WAKE_TIME` write/read
  - sets and verifies `AUTO_BOOT=0`
- Runtime/cache/fallback directory creation and read/write/delete tests:
  - `/var/log/nereus`
  - `/var/log/nereus/health`
  - `/var/lib/nereus`
  - `/var/lib/nereus/cache`
  - `/var/lib/nereus/offline`
  - `/var/lib/nereus/images`
  - `/var/tmp/nereus-transient`
  - `/mnt/nereus-media/images` when external media is mounted
- LTE end-to-end validation over `wwan0`.
- GPS raw/NMEA enabled and checked, but GPS fix is not required.
- Tailscale authentication remains a hard gate.
- Prototype passwordless sudo remains intentional for first production run.
- Active runtime code is scanned for old Witty Pi runtime references.
- LTE identity inventory capture:
  - modem IMEI
  - SIM ICCID
  - cellular operator ID/name when available
  - writes `/etc/nereus/device_identity.json`
  - writes env values: `MODEM_IMEI`, `SIM_ICCID`, `CELLULAR_OPERATOR_ID`, `CELLULAR_OPERATOR_NAME`, `DEVICE_IDENTITY_PATH`

## Validation run

The included `install.sh` was checked with:

```bash
bash -n install.sh
```

The zip was checked with:

```bash
unzip -t nereus-deploy-production-installer-hardening-v4.9-imei-iccid.zip
```
