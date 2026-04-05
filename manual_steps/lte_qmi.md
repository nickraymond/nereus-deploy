Use a separate terminal/session for LTE bring-up.

1. Verify hardware enumerates:

   lsusb
   ls /dev/ttyUSB*

2. Install minicom if needed (the installer already did this):

   sudo minicom -D /dev/ttyUSB2 -b 115200

3. In minicom, verify:
   AT
   AT+CPIN?
   AT+CSQ
   AT+CEREG?

4. Set APN:
   AT+CGDCONT=1,"IP","iot0723.com.attz"

5. Set modem USB mode:
   AT#USBCFG=0
   AT#REBOOT

6. After modem reboot:

   sudo systemctl restart ModemManager
   sudo systemctl restart NetworkManager
   sleep 5

7. Verify QMI path:

   ls /dev/cdc-wdm*
   lsmod | grep -E 'qmi|wwan|cdc_wdm|option'
   mmcli -L
   mmcli -m 0
   nmcli device status

8. If needed, recreate LTE profile:

   sudo nmcli connection delete lte 2>/dev/null || true
   sudo nmcli connection add type gsm ifname cdc-wdm0 con-name lte apn iot0723.com.attz
   sudo nmcli connection up lte

9. Verify data path:

   ip a
   ip route
   ping -I wwan0 1.1.1.1
   curl --interface wwan0 https://nereus-vision-dev.onrender.com

If LTE is not needed yet, choose skip when you return to the installer.
