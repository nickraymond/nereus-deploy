# Witty Pi legacy configuration

Witty Pi is retained for backwards-compatible devices. New systems should use LiFePO4wered/Pi+ unless there is a specific reason to keep Witty Pi.

1. Launch the Witty Pi CLI:

```bash
cd ~/wittypi/Software/wittypi
sudo ./wittyPi.sh
```

2. In the menu:

```text
[11] Change other settings
[1] Default state when powered -> ON
[13] Exit
```

3. Confirm the log files are owned by `pi:pi`:

```bash
ls -lah ~/wittypi/Software/wittypi
```

4. Optionally inspect:

```bash
~/wittypi/Software/wittypi/wittyPi.log
~/wittypi/Software/wittypi/schedule.log
```

5. Confirm env compatibility:

```bash
sudo grep -E 'ENABLE_POWER_CONTROLLER|POWER_CONTROLLER_BACKEND|ENABLE_WITTYPI' /etc/nereus/nereus-agent.env
```

For Witty Pi hardware, expected values are typically:

```bash
ENABLE_POWER_CONTROLLER=true
POWER_CONTROLLER_BACKEND=auto
ENABLE_WITTYPI=true
```
