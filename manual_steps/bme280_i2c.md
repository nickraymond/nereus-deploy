# BME280 / I2C validation

Goal: verify the BME280 can be read directly and that the agent health path reports internal environment data.

## 1. Confirm I2C device exists

```bash
ls -l /dev/i2c-1
```

If `/dev/i2c-1` is missing, enable I2C and reboot:

```bash
sudo raspi-config nonint do_i2c 0
sudo reboot
```

## 2. Scan the I2C bus

```bash
i2cdetect -y 1
```

Expected for current Nereus wiring:

```text
0x77
```

Some boards use `0x76`; the agent is configured to try both.

## 3. Run a direct BME280 read test

```bash
cd /home/pi/code/nereus-vision-dev/device/system_agent
source .venv/bin/activate
python - <<'PY'
import board
import busio
from adafruit_bme280 import basic as adafruit_bme280

i2c = busio.I2C(board.SCL, board.SDA)

for address in (0x77, 0x76):
    try:
        bme = adafruit_bme280.Adafruit_BME280_I2C(i2c, address=address)
        print("BME280 OK address=", hex(address))
        print("temp_c=", bme.temperature)
        print("rh_pct=", bme.relative_humidity)
        print("pressure_hpa=", bme.pressure)
        break
    except Exception as exc:
        print("BME280 failed address=", hex(address), "error=", repr(exc))
PY
```

## 4. Confirm agent env

```bash
sudo grep -Ei 'ENABLE_SYSTEM_HEALTH_MONITORING|ENABLE_BME280|BME280|HEALTH_LOG_DIR' /etc/nereus/nereus-agent.env
```

Expected:

```text
ENABLE_SYSTEM_HEALTH_MONITORING=true
ENABLE_BME280_INTERNAL_ENV=true
BME280_I2C_BUS=1
BME280_I2C_ADDRESSES=0x77,0x76
```

## 5. Restart the agent and confirm BME reporting

```bash
sudo systemctl restart nereus-agent
sleep 10
sudo grep -Ei 'bme280|internal_temp|internal_rh|internal_pressure|health' \
  /var/log/nereus/agent.log /var/log/nereus/agent.err.log | tail -120
```

Common failures:

- No address in `i2cdetect`: check power, ground, SDA, and SCL.
- `Remote I/O error`: wrong address, swapped SDA/SCL, loose wiring, or bus conflict.
- Direct read works but agent does not report BME: confirm `ENABLE_SYSTEM_HEALTH_MONITORING=true`.
