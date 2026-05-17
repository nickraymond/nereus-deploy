# LiFePO4wered/Pi+ validation

Goal: verify the LiFePO4wered/Pi+ is visible, readable, and configured for unattended solar/battery recovery.

## 1. Confirm I2C visibility

```bash
i2cdetect -y 1
```

Expected: LiFePO4wered/Pi+ typically appears near `0x43`.

## 2. Confirm the CLI can read the board

```bash
which lifepo4wered-cli
lifepo4wered-cli get
```

Useful quick reads:

```bash
lifepo4wered-cli get VBAT
lifepo4wered-cli get VIN
lifepo4wered-cli get VOUT
lifepo4wered-cli get IOUT
lifepo4wered-cli get RTC_TIME
```

## 3. Confirm auto-boot for field recovery

For field/solar deployments, the board should power the Pi back on automatically when power/battery recovers.

```bash
lifepo4wered-cli get AUTO_BOOT
lifepo4wered-cli set AUTO_BOOT 1
lifepo4wered-cli get AUTO_BOOT
```

Expected:

```text
AUTO_BOOT=1
```

## 4. Confirm the daemon

```bash
sudo systemctl status lifepo4wered-daemon --no-pager
journalctl -u lifepo4wered-daemon -n 80 --no-pager
```

## 5. Confirm agent env

```bash
sudo grep -E 'ENABLE_POWER_CONTROLLER|POWER_CONTROLLER_BACKEND|ENABLE_WITTYPI' /etc/nereus/nereus-agent.env
```

Expected for LiFePO4wered/Pi+:

```text
ENABLE_POWER_CONTROLLER=true
POWER_CONTROLLER_BACKEND=auto
ENABLE_WITTYPI=false
```

## 6. Field recovery acceptance test

Before deployment, test the full behavior with the real battery/solar hardware:

1. Let the board shut the Pi down/off due to low battery.
2. Apply solar/input power.
3. Confirm the battery charges.
4. Confirm the Pi powers back on without pressing the button.
5. Confirm `nereus-agent` starts and reports telemetry.
