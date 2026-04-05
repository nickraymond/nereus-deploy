Witty Pi configuration is manual.

1. Launch the Witty Pi CLI:
   cd ~/wittypi/Software/wittypi
   sudo ./wittyPi.sh

2. In the menu:
   [11] Change other settings
   [1] Default state when powered -> ON
   [13] Exit

3. Confirm the log files are owned by pi:pi:
   ls -lah ~/wittypi/Software/wittypi

4. Optionally inspect:
   ~/wittypi/Software/wittypi/wittyPi.log
   ~/wittypi/Software/wittypi/schedule.log
