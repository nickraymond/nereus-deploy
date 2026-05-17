# Staging branch requirements notes

These are the dependency updates that should also be reflected in the private `nereus-vision-dev` repo on the `staging` branch so the app requirements stay self-documenting.

## `device/system_agent/requirements.txt`

Add these lines if they are not already present:

```text
adafruit-blinka
adafruit-circuitpython-bme280
```

The deploy installer installs these directly into the system-agent venv as a safety net, but the private app repo should own them long-term because the BME280 read path is part of the agent runtime.

## OS packages needed on Raspberry Pi OS

The deploy installer now installs these packages:

```bash
sudo apt install -y python3-pip python3-venv i2c-tools build-essential libsystemd-dev
```

`i2c-tools` is needed for bus validation with `i2cdetect`.
`build-essential` and `libsystemd-dev` are needed to build/install `lifepo4wered-cli` and `lifepo4wered-daemon` from `xorbit/LiFePO4wered-Pi`.

## Runtime env naming

New code should prefer:

```bash
ENABLE_POWER_CONTROLLER=true
POWER_CONTROLLER_BACKEND=auto
```

Keep legacy compatibility with:

```bash
ENABLE_WITTYPI=true|false
```

but do not use `ENABLE_WITTYPI` as the primary new configuration key.
