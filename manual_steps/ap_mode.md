# Field service Wi-Fi AP validation

Goal: confirm the Pi is broadcasting the field-service Wi-Fi access point.

The installer creates the NetworkManager AP profile automatically.

Expected AP name pattern:

```text
NEREUS <SYSTEM_ID>
```

Example:

```text
NEREUS SYS_0003
```

## 1. Confirm NetworkManager state

```bash
nmcli device status
```

Expected pattern:

```text
wlan0          wifi      connected               FieldCam-AP
eth0           ethernet  connected               Wired connection 1
cdc-wdm0       gsm       connected               lte
tailscale0     tun       connected (externally)  tailscale0
lo             loopback  connected (externally)  lo
```

## 2. Confirm the AP connection details

```bash
nmcli connection show FieldCam-AP
```

## 3. Test from a phone or laptop

1. Scan for Wi-Fi networks.
2. Connect to `NEREUS <SYSTEM_ID>`.
3. Use password `nereus-vision` unless changed.
4. Confirm the client connects.
5. Optional: open the fieldcam service page or test the Pi at `10.42.0.1`.

Common failures:

- AP name shows literal `NEREUS ${SYSTEM_ID}`: installer variable expansion bug.
- `wlan0` unavailable: Wi-Fi is blocked, disabled, or already managed by another profile.
- Cannot connect: check WPA password and AP profile settings.
- AP visible but service unavailable: check `sudo systemctl status fieldcam --no-pager`.
