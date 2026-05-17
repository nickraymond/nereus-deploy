# LiFePO4wered/Pi+ validation

LiFePO4wered/Pi+ is the current Nereus power-controller path.

The installer clones and builds:

```bash
https://github.com/xorbit/LiFePO4wered-Pi.git
```

It runs:

```bash
make all
sudo make user-install
```

## 1. Confirm I2C is available

```bash
ls -l /dev/i2c-1
i2cdetect -y 1
```

You should see the LiFePO4wered/Pi+ I2C device on the bus. Your current system has shown it near `0x43`.

## 2. Confirm the CLI is installed

```bash
which lifepo4wered-cli
lifepo4wered-cli get
```

Useful quick reads:

```bash
lifepo4wered-cli get vbat
lifepo4wered-cli get vin
lifepo4wered-cli get vout
lifepo4wered-cli get iout
lifepo4wered-cli get rtc_time
```

## 3. Confirm the daemon

```bash
sudo systemctl status lifepo4wered-daemon --no-pager
journalctl -u lifepo4wered-daemon -n 80 --no-pager
```

## 4. Agent env check

```bash
sudo grep -E 'ENABLE_POWER_CONTROLLER|POWER_CONTROLLER_BACKEND|ENABLE_WITTYPI' /etc/nereus/nereus-agent.env
```

For the current LiFePO4wered/Pi+ path, expected values are:

```bash
ENABLE_POWER_CONTROLLER=true
POWER_CONTROLLER_BACKEND=auto
ENABLE_WITTYPI=false
```

## 5. Notes

Do not write permanent LiFePO4wered/Pi+ flash settings until the wake/sleep behavior has been tested. Runtime settings can be recovered by removing power and the cell; flash settings are persistent.
