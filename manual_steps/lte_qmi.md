# LTE modem bring-up / QMI validation

Goal: verify the Telit modem is on the QMI path and LTE traffic works.

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

Expected:

```text
/org/freedesktop/ModemManager1/Modem/0 [Telit] LE910C4-NF
cdc-wdm0    gsm    connected    lte
```

Do not create or activate the LTE profile until `mmcli -L` shows the modem.

## 3. Create/recreate the LTE profile if needed

```bash
sudo nmcli connection delete lte 2>/dev/null || true
sudo nmcli connection add type gsm ifname cdc-wdm0 con-name lte apn iot0723.com.attz
sudo nmcli connection up lte
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

## 5. APN and AT-console checks if needed

Only use the AT console if the modem is not registering or the APN needs to be checked.

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
