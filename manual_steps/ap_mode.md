# Setup wlan0 AP (optional)

Use this only if you want the Pi to host its own local access point for field use.

## 1. Unblock Wi-Fi

```bash
sudo rfkill unblock wifi
sudo nmcli radio wifi on
```

## 2. Create the AP connection file

```bash
sudo nano /etc/NetworkManager/system-connections/FieldCam-AP.nmconnection
```

Paste and adjust the `ssid` if needed:

```ini
[connection]
id=FieldCam-AP
type=wifi
interface-name=wlan0

[wifi]
band=bg
mode=ap
ssid=NEREUS SYS_002

[wifi-security]
key-mgmt=wpa-psk
psk=nereus-vision

[ipv4]
address1=10.42.0.1/24
method=shared

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
```

## 3. Fix permissions

```bash
sudo chown root:root /etc/NetworkManager/system-connections/FieldCam-AP.nmconnection
sudo chmod 600 /etc/NetworkManager/system-connections/FieldCam-AP.nmconnection
```

## 4. Restart NetworkManager

```bash
sudo systemctl restart NetworkManager
sleep 5
```

## 5. Bring the AP up

```bash
sudo nmcli connection up FieldCam-AP
```

## 6. Verify it worked

You want to see:
- `FieldCam-AP` in the connection list
- `wlan0` connected to `FieldCam-AP`
- `wlan0` with `10.42.0.1/24`

## 7. Test from a client device

On your phone or laptop:
1. connect to the SSID
2. use password `nereus-vision`
3. verify you can reach the Pi at `10.42.0.1`

If your field app uses port 8080, test:

```bash
curl http://10.42.0.1:8080
```
