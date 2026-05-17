# Camera and hardware validation

Suggested checks:

## 1. Service status

```bash
sudo systemctl status nereus-agent --no-pager
sudo systemctl status fieldcam --no-pager
```

## 2. Agent logs

```bash
sudo tail -f /var/log/nereus/agent.log
```

## 3. Camera detection

```bash
rpicam-hello --list-cameras
```

## 4. Test capture

```bash
mkdir -p /tmp/nereus-camera-test
rpicam-still -o /tmp/nereus-camera-test/test.jpg --timeout 1000
ls -lah /tmp/nereus-camera-test/test.jpg
```

## 5. Agent capture behavior

Verify images appear in one of these locations depending on config and storage state:

```bash
ls -lah /var/lib/nereus/images
ls -lah /mnt/nereus-media
```

## 6. Dashboard / backend

Verify:
- telemetry is received
- latest image updates
- mode/config changes are received by the device
- cycle logs arrive if remote cycle logs are enabled
