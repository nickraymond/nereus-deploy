LTE modem bring-up stays manual in v1.

Suggested sequence:
1. Verify hardware:
   lsusb
   ls /dev/ttyUSB*
2. Install minicom if needed:
   sudo apt-get install -y minicom
3. Open modem console:
   sudo minicom -D /dev/ttyUSB2 -b 115200
4. Check:
   AT+CPIN?
   AT+CSQ
   AT+CEREG?
5. Set APN:
   AT+CGDCONT=1,"IP","iot0723.com.attz"
6. Match working USB mode:
   AT#USBCFG=0
   AT#REBOOT
7. Restart managers:
   sudo systemctl restart ModemManager
   sudo systemctl restart NetworkManager
8. Verify QMI path:
   ls /dev/cdc-wdm*
   mmcli -L
   nmcli device status
9. Create LTE profile if needed:
   sudo nmcli connection add type gsm ifname cdc-wdm0 con-name lte apn iot0723.com.attz
   sudo nmcli connection up lte
10. Verify traffic over LTE:
   ping -I wwan0 1.1.1.1
