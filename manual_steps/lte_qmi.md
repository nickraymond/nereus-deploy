# LTE modem bring-up / QMI validation

Goal: verify the Telit modem is on the QMI path and LTE traffic works.

The normal bring-up path is now NetworkManager + ModemManager. AT commands are debug-only.

The installer installs the LTE packages, enables ModemManager, retriggers udev, and adds the noninteractive `mmcli` sudo rule used by the agent.

## 1. Verify hardware enumeration

```bash
lsusb
lsusb -t
ls -l /dev/ttyUSB* /dev/cdc-wdm* 2>/dev/null || true
lsmod | grep -E 'qmi|wwan|cdc_wdm|option|usbserial'
```

Expected success signs:

```text
Telit Wireless Solutions LE910 / LE920
/dev/cdc-wdm0
qmi_wwan
cdc_wdm
```

`cdc-wdm0` is the modem control/QMI device. `wwan0` is the data interface that gets the IP address and carries traffic.

## 2. Verify ModemManager sees the modem

```bash
sudo systemctl restart ModemManager
sudo systemctl restart NetworkManager
sudo udevadm control --reload-rules
sudo udevadm trigger
sleep 10

mmcli -L
nmcli device status
```

Expected modem visibility:

```text
/org/freedesktop/ModemManager1/Modem/0 [Telit] LE910C4-NF
```

Expected NetworkManager state before the LTE profile is activated:

```text
cdc-wdm0    gsm    disconnected    --
```

That disconnected state is okay. It means the modem is visible and ready, but no data session is active yet.

Do not create or activate the LTE profile until `mmcli -L` shows the modem and `nmcli device status` shows `cdc-wdm0` as a GSM device.

## 3. Create/recreate the LTE profile if needed

```bash
sudo nmcli connection delete lte 2>/dev/null || true
sudo nmcli connection add type gsm ifname cdc-wdm0 con-name lte apn iot0723.com.attz
sudo nmcli connection up lte
```

Expected after activation:

```text
cdc-wdm0    gsm    connected    lte
```

## 4. Verify data path over LTE

```bash
ip a show wwan0
ip route
ping -I wwan0 1.1.1.1
curl --interface wwan0 https://nereus-vision-staging.onrender.com
```

Expected:

```text
wwan0 has an IPv4 address
ping -I wwan0 works
curl --interface wwan0 reaches the backend
```

A successful backend response looks like:

```json
{"status":"ok","message":"Nereus Vision API running"}
```

## 5. AT-console checks only if needed

Only use the AT console if one of these fails:

- `lsusb` does not show Telit
- `/dev/cdc-wdm0` is missing
- `mmcli -L` shows no modems after ModemManager restart + udev trigger
- SIM is not ready
- modem is not registering
- APN profile fails repeatedly

```bash
sudo minicom -D /dev/ttyUSB2 -b 115200
```

Useful AT checks:

```text
AT
AT+CPIN?
AT+CSQ
AT+CEREG?
AT+CGDCONT?
AT+CGDCONT=1,"IP","iot0723.com.attz"
```

## 6. USB mode note

Do not force `AT#USBCFG=0` when `/dev/cdc-wdm0` exists and `qmi_wwan` is loaded.

Only investigate `AT#USBCFG` if `/dev/cdc-wdm0` is missing.

## 7. Agent compatibility note

For telemetry/back-end compatibility, report the LTE data interface as:

```text
uplink_interface=wwan0
```

`cdc-wdm0` is the modem control interface, not the packet data interface.
