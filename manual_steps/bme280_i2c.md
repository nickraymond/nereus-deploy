# BME280 / I2C validation

The installer installs the needed OS and Python dependencies:

```bash
sudo apt install -y python3-pip python3-venv i2c-tools
```

Inside the system-agent virtual environment it installs:

```bash
pip install adafruit-blinka adafruit-circuitpython-bme280
```

## 1. Confirm I2C is enabled

```bash
ls -l /dev/i2c-1
```

If `/dev/i2c-1` is missing, enable I2C and reboot:

```bash
sudo raspi-config nonint do_i2c 0
sudo reboot
```

## 2. Confirm the sensor appears on the bus

```bash
i2cdetect -y 1
```

Expected for your current wiring:

```text
0x77
```

Some BME280 breakout boards use `0x76`; the agent config/code should match the actual address.

## 3. Confirm imports from the agent venv

```bash
cd /home/pi/code/nereus-vision-dev/device/system_agent
source .venv/bin/activate
python - <<'PY'
import board
import busio
import adafruit_bme280
print('BME280 imports OK')
PY
```

## 4. Optional direct read test

Use `0x77` if that is what `i2cdetect` shows.

```bash
cd /home/pi/code/nereus-vision-dev/device/system_agent
source .venv/bin/activate
python - <<'PY'
import board
import busio
from adafruit_bme280 import basic as adafruit_bme280

i2c = busio.I2C(board.SCL, board.SDA)
bme280 = adafruit_bme280.Adafruit_BME280_I2C(i2c, address=0x77)
print('temp_c=', bme280.temperature)
print('rh_pct=', bme280.relative_humidity)
print('pressure_hpa=', bme280.pressure)
PY
```

## 5. Common failures

- `Remote I/O error` usually means wrong address, swapped SDA/SCL, weak/loose wiring, or an I2C bus conflict.
- If `i2cdetect` shows no address, fix wiring before debugging Python.
- If `i2cdetect` shows `0x76` but code uses `0x77`, update the address.
