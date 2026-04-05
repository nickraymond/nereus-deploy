Run these steps in another terminal/session.

1. If the installer just completed Witty Pi installation, reboot the Pi first if needed.

2. Launch the Witty Pi CLI:

   cd ~/wittypi/Software/wittypi
   sudo ./wittyPi.sh

3. In the control software:
   [11] Change other settings
   [1]  Default state when powered -> set to ON
   [13] Exit

4. Fix log ownership so the code can read the log files:

   sudo chown pi:pi /home/pi/wittypi/Software/wittypi/wittyPi.log
   sudo chown pi:pi /home/pi/wittypi/Software/wittypi/schedule.log
   sudo chmod 664 /home/pi/wittypi/Software/wittypi/wittyPi.log
   sudo chmod 664 /home/pi/wittypi/Software/wittypi/schedule.log

5. Verify:

   ls -lah /home/pi/wittypi/Software/wittypi

Return here only after the interactive Witty Pi setup is complete.
