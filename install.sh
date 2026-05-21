#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
MANUAL_DIR="${SCRIPT_DIR}/manual_steps"

DEFAULT_API_BASE="https://nereus-vision-dev.onrender.com"
DEFAULT_REPO_SSH_URL="git@github.com:nickraymond/nereus-vision-dev.git"
DEFAULT_REPO_BRANCH="staging"
DEFAULT_REPO_DIR="$HOME/code/nereus-vision-dev"
STATE_DIR="$HOME/.nereus-deploy"
STATE_FILE="${STATE_DIR}/install.env"

mkdir -p "${STATE_DIR}"

log() { printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { log "[error] $*"; exit 1; }

normalize_url_no_trailing_slash() {
  local value="$1"
  while [[ "${value}" == */ ]]; do
    value="${value%/}"
  done
  printf '%s' "${value}"
}

wait_for_apt_lock() {
  local max_wait_sec="${1:-300}"
  local waited=0
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
     || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
     || sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if (( waited >= max_wait_sec )); then
      die "Timed out waiting for apt/dpkg lock after ${max_wait_sec}s. Another package process may be stuck."
    fi
    log "[apt] another apt/dpkg process is running; waiting..."
    sleep 10
    waited=$((waited + 10))
  done
  sudo dpkg --configure -a
}

apt_get_update_safe() {
  wait_for_apt_lock 300
  sudo apt-get update
}

apt_get_install_safe() {
  wait_for_apt_lock 300
  sudo apt-get install -y "$@"
}


ensure_state_file() { touch "${STATE_FILE}"; }

save_state_var() {
  local key="$1"
  local value="$2"
  ensure_state_file
  python3 - "$STATE_FILE" "$key" "$value" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1]); key = sys.argv[2]; value = sys.argv[3]
lines = p.read_text().splitlines() if p.exists() else []
out = []
done = False
for line in lines:
    if line.startswith(key + "="):
        out.append(f'{key}="{value}"')
        done = True
    else:
        out.append(line)
if not done:
    out.append(f'{key}="{value}"')
p.write_text("\n".join(out) + "\n")
PY
}

load_state() {
  if [[ -f "${STATE_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
  fi
}

mark_step_done() {
  local step="$1"
  save_state_var "STEP_${step}" "done"
}

prompt_default() {
  local prompt="$1"
  local default="$2"
  local reply
  read -r -p "${prompt} [${default}]: " reply
  if [[ -z "${reply}" ]]; then printf '%s' "${default}"; else printf '%s' "${reply}"; fi
}

prompt_required() {
  local prompt="$1"
  local reply
  while true; do
    read -r -p "${prompt}: " reply
    if [[ -n "${reply}" ]]; then printf '%s' "${reply}"; return; fi
    echo "Value is required."
  done
}

prompt_confirm_twice() {
  local label="$1"
  local value1 value2
  while true; do
    value1="$(prompt_required "${label}")"
    value2="$(prompt_required "Re-enter ${label}")"
    if [[ "${value1}" == "${value2}" ]]; then
      printf '%s' "${value1}"
      return
    fi
    echo "Values did not match. Please try again."
  done
}

prompt_yes_no_default_yes() {
  local prompt="$1" reply
  while true; do
    read -r -p "${prompt} [Y/n]: " reply
    case "${reply:-Y}" in
      Y|y) return 0 ;;
      N|n) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

prompt_yes_no_default_no() {
  local prompt="$1" reply
  while true; do
    read -r -p "${prompt} [y/N]: " reply
    case "${reply:-N}" in
      Y|y) return 0 ;;
      N|n) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

manual_checkpoint() {
  local title="$1"
  local file="$2"
  echo
  echo "=================================================================="
  echo "${title}"
  echo "=================================================================="
  cat "${MANUAL_DIR}/${file}"
  echo
  echo "Do the manual steps in another terminal/session, then return here."
  while true; do
    read -r -p "Did this manual step succeed? [y/n/skip]: " reply
    case "${reply}" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
      skip|SKIP|Skip) return 2 ;;
      *) echo "Please answer y, n, or skip." ;;
    esac
  done
}

maybe_resume_existing_state() {
  load_state
  if [[ -f "${STATE_FILE}" ]] && [[ -n "${INSTALLER_VERSION:-}" ]]; then
    echo
    echo "Existing install state found at ${STATE_FILE}"
    if prompt_yes_no_default_yes "Resume previous install state?"; then
      log "[state] resuming prior installer state"
      return
    fi
    if prompt_yes_no_default_no "Clear prior install state and start over?"; then
      rm -f "${STATE_FILE}"
      load_state
      log "[state] cleared previous installer state"
      return
    fi
    die "Installer aborted."
  fi
}

require_sudo() { sudo -v || die "sudo access is required"; }

setup_prototype_passwordless_sudo() {
  [[ "${STEP_PASSWORDLESS_SUDO:-}" == "done" ]] && return 0
  log "[sudo] enabling prototype passwordless sudo for pi"
  sudo tee /etc/sudoers.d/010-pi-nopasswd >/dev/null <<'EOF'
pi ALL=(ALL) NOPASSWD:ALL
EOF
  sudo chown root:root /etc/sudoers.d/010-pi-nopasswd
  sudo chmod 440 /etc/sudoers.d/010-pi-nopasswd

  # Remove older narrow rules. The prototype-wide rule above supersedes these
  # and avoids hidden noninteractive sudo failures as the agent evolves.
  sudo rm -f /etc/sudoers.d/nereus-mmcli /etc/sudoers.d/nereus-storage /etc/sudoers.d/nereus-power

  sudo visudo -c >/dev/null
  sudo -n true || die "passwordless sudo validation failed"

  if command -v shutdown >/dev/null 2>&1; then
    sudo -n "$(command -v shutdown)" --help >/dev/null || die "shutdown sudo validation failed"
  fi
  if command -v poweroff >/dev/null 2>&1; then
    sudo -n "$(command -v poweroff)" --help >/dev/null || die "poweroff sudo validation failed"
  fi

  log "[sudo] passwordless sudo OK; obsolete narrow sudoers rules removed"
  mark_step_done PASSWORDLESS_SUDO
}

check_platform() {
  [[ -f /etc/os-release ]] || die "Cannot detect OS"
  if ! grep -qiE 'debian|raspbian|ubuntu' /etc/os-release; then
    die "This installer expects Raspberry Pi OS / Debian-like Linux"
  fi
}

check_network() {
  if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 && ! ping -c 1 -W 2 github.com >/dev/null 2>&1; then
    die "Network connectivity appears unavailable"
  fi
}

preflight_questions() {
  [[ "${STEP_PREFLIGHT:-}" == "done" ]] && return 0

  echo
  echo "Nereus deploy preflight"
  echo "-----------------------"

  HOSTNAME_VALUE="$(prompt_default 'Pi hostname (example: cam02)' "${HOSTNAME_VALUE:-cam02}")"
  TAILSCALE_HOSTNAME="$(prompt_confirm_twice 'Tailscale hostname (example: nereus-sys-0002)')"
  SYSTEM_ID_VALUE="$(prompt_confirm_twice 'SYSTEM_ID (example: SYS_002)')"
  DEVICE_ID_VALUE="$(prompt_confirm_twice 'DEVICE_ID (example: CAM_002)')"
  API_BASE_VALUE="$(normalize_url_no_trailing_slash "$(prompt_default 'API base URL' "${API_BASE_VALUE:-$DEFAULT_API_BASE}")")"
  REPO_URL_VALUE="$(prompt_default 'Private repo SSH URL' "${REPO_URL_VALUE:-$DEFAULT_REPO_SSH_URL}")"
  REPO_BRANCH_VALUE="$(prompt_default 'Repo branch to install' "${REPO_BRANCH_VALUE:-$DEFAULT_REPO_BRANCH}")"
  REPO_DIR_VALUE="$(prompt_default 'Repo install directory' "${REPO_DIR_VALUE:-$DEFAULT_REPO_DIR}")"
  POWER_CONTROLLER_CHOICE_VALUE="lifepo4wered"
  ENABLE_POWER_CONTROLLER_VALUE="true"
  INSTALL_LIFEPO4WERED_VALUE="true"

  if prompt_yes_no_default_yes "Install Tailscale?"; then INSTALL_TAILSCALE_VALUE="true"; else INSTALL_TAILSCALE_VALUE="false"; fi
  ENABLE_TAILSCALE_SSH_VALUE="true"
  INSTALL_FIELDCAM_VALUE="true"
  if prompt_yes_no_default_yes "Configure wlan0 as FieldCam-AP?"; then CONFIGURE_AP_VALUE="true"; else CONFIGURE_AP_VALUE="false"; fi
  if prompt_yes_no_default_yes "Enable and start nereus-agent.service and fieldcam.service at end?"; then START_SERVICES_VALUE="true"; else START_SERVICES_VALUE="false"; fi

  local state_key
  for state_key in HOSTNAME_VALUE TAILSCALE_HOSTNAME SYSTEM_ID_VALUE DEVICE_ID_VALUE API_BASE_VALUE REPO_URL_VALUE REPO_BRANCH_VALUE REPO_DIR_VALUE POWER_CONTROLLER_CHOICE_VALUE ENABLE_POWER_CONTROLLER_VALUE INSTALL_LIFEPO4WERED_VALUE INSTALL_TAILSCALE_VALUE ENABLE_TAILSCALE_SSH_VALUE INSTALL_FIELDCAM_VALUE CONFIGURE_AP_VALUE START_SERVICES_VALUE; do
    if [[ -z "${!state_key+x}" ]]; then
      die "Internal installer error: expected ${state_key} to be set during preflight."
    fi
    save_state_var "$state_key" "${!state_key}"
  done

  if ! prompt_yes_no_default_no "Have SYSTEM_ID and DEVICE_ID already been created in the backend?"; then
    die "Register SYSTEM_ID and DEVICE_ID in the backend first, then rerun the installer."
  fi

  if ! prompt_yes_no_default_yes "Continue with hostname ${HOSTNAME_VALUE}, SYSTEM_ID ${SYSTEM_ID_VALUE}, DEVICE_ID ${DEVICE_ID_VALUE}, branch ${REPO_BRANCH_VALUE}?"; then
    die "Preflight confirmation failed."
  fi

  mark_step_done PREFLIGHT
}

apply_hostname() {
  [[ "${STEP_HOSTNAME:-}" == "done" ]] && return 0
  local current
  current="$(hostname)"
  if [[ "${current}" != "${HOSTNAME_VALUE}" ]]; then
    log "[host] setting hostname to ${HOSTNAME_VALUE}"
    echo "${HOSTNAME_VALUE}" | sudo tee /etc/hostname >/dev/null
    sudo hostnamectl set-hostname "${HOSTNAME_VALUE}"
  else
    log "[host] hostname already ${HOSTNAME_VALUE}"
  fi
  mark_step_done HOSTNAME
}

set_utc_timezone() {
  [[ "${STEP_TIMEZONE:-}" == "done" ]] && return 0
  log "[time] setting timezone to UTC"
  sudo timedatectl set-timezone UTC
  timedatectl || true
  cat /etc/adjtime || true
  mark_step_done TIMEZONE
}

ensure_private_repo_access() {
  [[ "${STEP_GITHUB_SSH:-}" == "done" ]] && return 0
  if [[ -d "${REPO_DIR_VALUE}/.git" ]]; then
    log "[repo] existing repo found at ${REPO_DIR_VALUE}; skipping GitHub SSH checkpoint"
    mark_step_done GITHUB_SSH
    return
  fi
  if ! manual_checkpoint "[manual] GitHub SSH setup" "github_ssh.md"; then
    die "GitHub SSH is required before cloning the private repo."
  fi
  mark_step_done GITHUB_SSH
}

install_base_packages() {
  [[ "${STEP_APT:-}" == "done" ]] && return 0
  log "[apt] installing base packages, I2C tools, camera tooling, LTE/QMI helpers, storage tools, and build tools"
  apt_get_update_safe
  apt_get_install_safe \
    git curl jq python3 python3-venv python3-pip \
    i2c-tools build-essential libsystemd-dev \
    rpicam-apps python3-picamera2 \
    network-manager modemmanager libqmi-utils usb-modeswitch minicom \
    exfatprogs dosfstools rfkill
  mark_step_done APT
}

setup_lte_userland() {
  [[ "${STEP_LTE_USERLAND:-}" == "done" ]] && return 0
  log "[lte] enabling ModemManager, restarting network managers, and retriggering udev"
  sudo systemctl enable --now ModemManager
  sudo systemctl restart ModemManager
  sudo systemctl restart NetworkManager
  sudo udevadm control --reload-rules
  sudo udevadm trigger
  sleep 10

  if command -v mmcli >/dev/null 2>&1; then
    log "[lte] validating mmcli can run noninteractively"
    sudo -n mmcli -L || true
  else
    log "[lte] mmcli not found after install; LTE manual validation will catch this"
  fi
  mark_step_done LTE_USERLAND
}


get_modem_id() {
  sudo -n mmcli -L 2>/dev/null | sed -n 's#.*Modem/\([0-9][0-9]*\).*#\1#p' | head -n 1
}

collect_lte_identity() {
  [[ "${STEP_LTE_IDENTITY:-}" == "done" ]] && return 0
  log "[lte] collecting modem IMEI and SIM ICCID inventory data"

  local modem_id modem_kv sim_path sim_id sim_kv imei iccid operator_id operator_name
  modem_id="$(get_modem_id || true)"
  if [[ -z "${modem_id}" ]]; then
    log "[lte] no modem found; writing unknown IMEI/ICCID values"
    MODEM_IMEI_VALUE="unknown"
    SIM_ICCID_VALUE="unknown"
    CELLULAR_OPERATOR_ID_VALUE="unknown"
    CELLULAR_OPERATOR_NAME_VALUE="unknown"
  else
    modem_kv="$(sudo -n mmcli -m "${modem_id}" --output-keyvalue 2>/dev/null || true)"
    imei="$(printf '%s\n' "${modem_kv}" | awk -F': ' '/modem\.generic\.equipment-identifier/ {print $2; exit}')"
    sim_path="$(printf '%s\n' "${modem_kv}" | awk -F': ' '/modem\.generic\.sim/ {print $2; exit}')"
    sim_id="$(basename "${sim_path:-}")"

    if [[ -n "${sim_id}" && "${sim_id}" != "--" && "${sim_id}" != "unknown" ]]; then
      sim_kv="$(sudo -n mmcli -i "${sim_id}" --output-keyvalue 2>/dev/null || true)"
      iccid="$(printf '%s\n' "${sim_kv}" | awk -F': ' '/sim\.properties\.iccid/ {print $2; exit}')"
      operator_id="$(printf '%s\n' "${sim_kv}" | awk -F': ' '/sim\.properties\.operator-identifier/ {print $2; exit}')"
      operator_name="$(printf '%s\n' "${sim_kv}" | awk -F': ' '/sim\.properties\.operator-name/ {print $2; exit}')"
    fi

    MODEM_IMEI_VALUE="${imei:-unknown}"
    SIM_ICCID_VALUE="${iccid:-unknown}"
    CELLULAR_OPERATOR_ID_VALUE="${operator_id:-unknown}"
    CELLULAR_OPERATOR_NAME_VALUE="${operator_name:-unknown}"
  fi

  save_state_var MODEM_IMEI_VALUE "${MODEM_IMEI_VALUE}"
  save_state_var SIM_ICCID_VALUE "${SIM_ICCID_VALUE}"
  save_state_var CELLULAR_OPERATOR_ID_VALUE "${CELLULAR_OPERATOR_ID_VALUE}"
  save_state_var CELLULAR_OPERATOR_NAME_VALUE "${CELLULAR_OPERATOR_NAME_VALUE}"

  log "[lte] IMEI=${MODEM_IMEI_VALUE} ICCID=${SIM_ICCID_VALUE} operator_id=${CELLULAR_OPERATOR_ID_VALUE} operator_name=${CELLULAR_OPERATOR_NAME_VALUE}"
  mark_step_done LTE_IDENTITY
}

write_device_identity_file() {
  [[ "${STEP_DEVICE_IDENTITY:-}" == "done" ]] && return 0
  log "[identity] writing /etc/nereus/device_identity.json"
  sudo mkdir -p /etc/nereus
  python3 - "${SYSTEM_ID_VALUE}" "${DEVICE_ID_VALUE}" "${TAILSCALE_HOSTNAME}" "${MODEM_IMEI_VALUE:-unknown}" "${SIM_ICCID_VALUE:-unknown}" "${CELLULAR_OPERATOR_ID_VALUE:-unknown}" "${CELLULAR_OPERATOR_NAME_VALUE:-unknown}" <<'IDENTITYPY' | sudo tee /etc/nereus/device_identity.json >/dev/null
import json
import sys
from datetime import datetime, timezone
payload = {
    "system_id": sys.argv[1],
    "device_id": sys.argv[2],
    "tailscale_hostname": sys.argv[3],
    "modem_imei": sys.argv[4],
    "sim_iccid": sys.argv[5],
    "cellular_operator_id": sys.argv[6],
    "cellular_operator_name": sys.argv[7],
    "created_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
}
print(json.dumps(payload, indent=2, sort_keys=True))
IDENTITYPY
  sudo chown root:root /etc/nereus/device_identity.json
  sudo chmod 600 /etc/nereus/device_identity.json
  mark_step_done DEVICE_IDENTITY
}

create_and_test_runtime_paths() {
  [[ "${STEP_RUNTIME_PATHS:-}" == "done" ]] && return 0
  log "[paths] creating runtime/cache/fallback directories and running read/write/delete tests"

  sudo mkdir -p \
    /var/log/nereus/health \
    /var/lib/nereus/cache \
    /var/lib/nereus/offline \
    /var/lib/nereus/images \
    /var/tmp/nereus-transient \
    /mnt/nereus-media/images

  sudo chown -R pi:pi /var/log/nereus /var/lib/nereus /var/tmp/nereus-transient
  sudo chmod 775 /var/tmp/nereus-transient

  local dir test_file
  for dir in \
    /var/log/nereus \
    /var/log/nereus/health \
    /var/lib/nereus \
    /var/lib/nereus/cache \
    /var/lib/nereus/offline \
    /var/lib/nereus/images \
    /var/tmp/nereus-transient
  do
    test_file="${dir}/.nereus_write_test"
    echo test > "${test_file}" || die "Runtime path not writable: ${dir}"
    cat "${test_file}" >/dev/null || die "Runtime path not readable: ${dir}"
    rm -f "${test_file}" || die "Runtime path cleanup failed: ${dir}"
    log "[paths] OK writable ${dir}"
  done

  if mountpoint -q /mnt/nereus-media; then
    sudo chown -R pi:pi /mnt/nereus-media || true
    test_file="/mnt/nereus-media/images/.nereus_write_test"
    if echo test > "${test_file}" && cat "${test_file}" >/dev/null && rm -f "${test_file}"; then
      log "[paths] OK writable /mnt/nereus-media/images"
    else
      log "[paths] WARNING external media mounted but /mnt/nereus-media/images write test failed"
    fi
  else
    log "[paths] external media not mounted; skipping external SD write test"
  fi

  mark_step_done RUNTIME_PATHS
}

verify_lifepo4wered_hard_gate() {
  [[ "${STEP_LIFEPO4WERED_VERIFY:-}" == "done" ]] && return 0
  log "[lifepo4wered] hard-gate verification"
  command -v lifepo4wered-cli >/dev/null 2>&1 || die "lifepo4wered-cli not found"

  local reg rtc_time old_wake test_wake readback auto_boot vbat vin
  reg="$(lifepo4wered-cli get I2C_REG_VER 2>/dev/null || true)"
  [[ "${reg}" =~ ^[0-9]+$ ]] || die "LiFePO4wered I2C_REG_VER read failed; got '${reg}'"

  rtc_time="$(lifepo4wered-cli get RTC_TIME 2>/dev/null || true)"
  [[ "${rtc_time}" =~ ^[0-9]+$ ]] || die "LiFePO4wered RTC_TIME read failed; got '${rtc_time}'"

  old_wake="$(lifepo4wered-cli get RTC_WAKE_TIME 2>/dev/null || true)"
  test_wake=$((rtc_time + 600))
  lifepo4wered-cli set RTC_WAKE_TIME "${test_wake}" >/dev/null
  readback="$(lifepo4wered-cli get RTC_WAKE_TIME 2>/dev/null || true)"
  [[ "${readback}" == "${test_wake}" ]] || die "LiFePO4wered RTC_WAKE_TIME verify failed; requested=${test_wake} readback=${readback}"
  if [[ "${old_wake}" =~ ^[0-9]+$ ]]; then
    lifepo4wered-cli set RTC_WAKE_TIME "${old_wake}" >/dev/null || true
  fi

  lifepo4wered-cli set AUTO_BOOT 0 >/dev/null
  auto_boot="$(lifepo4wered-cli get AUTO_BOOT 2>/dev/null || true)"
  [[ "${auto_boot}" == "0" ]] || die "LiFePO4wered AUTO_BOOT verify failed; expected 0 got ${auto_boot}"

  vbat="$(lifepo4wered-cli get VBAT 2>/dev/null || true)"
  vin="$(lifepo4wered-cli get VIN 2>/dev/null || true)"
  log "[lifepo4wered] OK I2C_REG_VER=${reg} RTC_TIME=${rtc_time} AUTO_BOOT=${auto_boot} VBAT=${vbat:-unknown} VIN=${vin:-unknown}"
  mark_step_done LIFEPO4WERED_VERIFY
}

verify_lte_end_to_end() {
  [[ "${STEP_LTE_E2E:-}" == "done" ]] && return 0
  log "[lte] end-to-end wwan0 validation"
  sudo -n mmcli -L || die "mmcli cannot list modem"
  ip a show wwan0 || die "wwan0 interface missing"
  ip route || true
  ping -I wwan0 -c 3 -W 5 1.1.1.1 || die "wwan0 ping to 1.1.1.1 failed"
  curl --interface wwan0 --max-time 20 "${API_BASE_VALUE}/" || die "wwan0 curl to API failed"
  log "[lte] end-to-end validation OK"
  mark_step_done LTE_E2E
}

verify_gps_alive_nonblocking() {
  [[ "${STEP_GPS_ALIVE:-}" == "done" ]] && return 0
  log "[gps] enabling and checking GPS raw/NMEA; fix is not required"
  local modem_id
  modem_id="$(get_modem_id || true)"
  if [[ -z "${modem_id}" ]]; then
    log "[gps] WARNING no modem found; skipping GPS alive check"
    mark_step_done GPS_ALIVE
    return 0
  fi
  sudo -n mmcli -m "${modem_id}" --location-enable-gps-raw --location-enable-gps-nmea || true
  sudo -n mmcli -m "${modem_id}" --location-status || true
  sudo -n mmcli -m "${modem_id}" --location-get || true
  mark_step_done GPS_ALIVE
}

enable_i2c_if_possible() {
  [[ "${STEP_I2C_ENABLE:-}" == "done" ]] && return 0
  if command -v raspi-config >/dev/null 2>&1; then
    log "[i2c] enabling I2C via raspi-config"
    sudo raspi-config nonint do_i2c 0 || true
  else
    log "[i2c] raspi-config not found; skipping automatic I2C enable"
  fi
  if getent group i2c >/dev/null 2>&1; then
    sudo usermod -aG i2c pi || true
  fi
  mark_step_done I2C_ENABLE
}

clone_or_update_repo() {
  [[ "${STEP_REPO:-}" == "done" ]] && return 0
  mkdir -p "$(dirname "${REPO_DIR_VALUE}")"
  if [[ -d "${REPO_DIR_VALUE}/.git" ]]; then
    log "[repo] updating existing repo at ${REPO_DIR_VALUE} on ${REPO_BRANCH_VALUE}"
    git -C "${REPO_DIR_VALUE}" fetch origin
    git -C "${REPO_DIR_VALUE}" checkout "${REPO_BRANCH_VALUE}"
    git -C "${REPO_DIR_VALUE}" pull origin "${REPO_BRANCH_VALUE}"
  else
    log "[repo] cloning ${REPO_URL_VALUE} into ${REPO_DIR_VALUE}"
    git clone --branch "${REPO_BRANCH_VALUE}" "${REPO_URL_VALUE}" "${REPO_DIR_VALUE}"
  fi
  mark_step_done REPO
}

install_system_agent() {
  [[ "${STEP_AGENT:-}" == "done" ]] && return 0
  local agent_dir="${REPO_DIR_VALUE}/device/system_agent"
  [[ -d "${agent_dir}" ]] || die "system_agent directory not found at ${agent_dir}"
  log "[agent] creating venv and installing requirements"
  python3 -m venv "${agent_dir}/.venv"
  # shellcheck disable=SC1091
  source "${agent_dir}/.venv/bin/activate"
  pip install --upgrade pip wheel
  pip install -r "${agent_dir}/requirements.txt"
  pip install adafruit-blinka adafruit-circuitpython-bme280
  deactivate

  log "[agent] creating directories"
  sudo mkdir -p /etc/nereus
  create_and_test_runtime_paths

  log "[storage] validating noninteractive access for storage helper commands"
  sudo -n true || die "passwordless sudo is required for storage helpers"

  log "[agent] writing env file"
  sed \
    -e "s|__API_BASE__|${API_BASE_VALUE}|g" \
    -e "s|__SYSTEM_ID__|${SYSTEM_ID_VALUE}|g" \
    -e "s|__DEVICE_ID__|${DEVICE_ID_VALUE}|g" \
    -e "s|__SYSTEM_CONFIG_CACHE_PATH__|/var/lib/nereus/system_config_cache_${SYSTEM_ID_VALUE}.json|g" \
    -e "s|__ENABLE_POWER_CONTROLLER__|${ENABLE_POWER_CONTROLLER_VALUE}|g" \
    -e "s|__MODEM_IMEI__|${MODEM_IMEI_VALUE:-unknown}|g" \
    -e "s|__SIM_ICCID__|${SIM_ICCID_VALUE:-unknown}|g" \
    -e "s|__CELLULAR_OPERATOR_ID__|${CELLULAR_OPERATOR_ID_VALUE:-unknown}|g" \
    -e "s|__CELLULAR_OPERATOR_NAME__|${CELLULAR_OPERATOR_NAME_VALUE:-unknown}|g" \
    "${TEMPLATES_DIR}/nereus-agent.env.template" \
    | grep -Ev '^(ENABLE_WITTYPI|ALLOW_WITTYPI_FALLBACK|INSTALL_WITTYPI|WITTYPI_SCHEDULE_STATE_PATH)=' \
    | sudo tee /etc/nereus/nereus-agent.env >/dev/null

  log "[agent] removing obsolete power-controller env vars from local env"
  sudo sed -i '/^ENABLE_WITTYPI=/d;/^ALLOW_WITTYPI_FALLBACK=/d;/^INSTALL_WITTYPI=/d;/^WITTYPI_SCHEDULE_STATE_PATH=/d' /etc/nereus/nereus-agent.env
  sudo chown root:root /etc/nereus/nereus-agent.env
  sudo chmod 600 /etc/nereus/nereus-agent.env
  write_device_identity_file

  log "[agent] writing systemd service"
  sed -e "s|__REPO_DIR__|${REPO_DIR_VALUE}|g" "${TEMPLATES_DIR}/nereus-agent.service.template" | sudo tee /etc/systemd/system/nereus-agent.service >/dev/null
  sudo rm -f /var/lib/nereus/system_config_cache*.json
  sudo systemctl daemon-reload
  sudo systemctl enable nereus-agent
  mark_step_done AGENT
}

install_fieldcam_required() {
  [[ "${STEP_FIELDCAM:-}" == "done" ]] && return 0
  local app_dir="${REPO_DIR_VALUE}/fieldcam_app"
  [[ -d "${app_dir}" ]] || die "fieldcam_app directory not found at ${app_dir}"
  log "[fieldcam] creating venv and installing requirements"
  rm -rf "${app_dir}/.venv"
  python3 -m venv --system-site-packages "${app_dir}/.venv"
  # shellcheck disable=SC1091
  source "${app_dir}/.venv/bin/activate"
  pip install --upgrade pip wheel
  pip install -r "${app_dir}/requirements.txt"
  deactivate
  log "[fieldcam] writing systemd service"
  sed -e "s|__REPO_DIR__|${REPO_DIR_VALUE}|g" "${TEMPLATES_DIR}/fieldcam.service.template" | sudo tee /etc/systemd/system/fieldcam.service >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable fieldcam
  mark_step_done FIELDCAM
}

install_lifepo4wered_if_selected() {
  [[ "${INSTALL_LIFEPO4WERED_VALUE}" == "true" ]] || return 0
  [[ "${STEP_LIFEPO4WERED:-}" == "done" ]] && return 0
  local lifepo_dir="$HOME/code/LiFePO4wered-Pi"
  mkdir -p "$HOME/code"
  if [[ -d "${lifepo_dir}/.git" ]]; then
    log "[lifepo4wered] updating existing source at ${lifepo_dir}"
    git -C "${lifepo_dir}" pull --ff-only || true
  else
    log "[lifepo4wered] cloning LiFePO4wered-Pi support software"
    git clone https://github.com/xorbit/LiFePO4wered-Pi.git "${lifepo_dir}"
  fi
  log "[lifepo4wered] building and installing CLI/daemon"
  make -C "${lifepo_dir}" all
  sudo make -C "${lifepo_dir}" user-install
  sudo systemctl daemon-reload || true
  sudo systemctl enable lifepo4wered-daemon.service 2>/dev/null || true
  sudo systemctl restart lifepo4wered-daemon.service 2>/dev/null || true
  mark_step_done LIFEPO4WERED
}

verify_tailscale_authenticated() {
  local ip status_output
  ip="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"
  status_output="$(tailscale status 2>&1 || true)"

  if [[ "${ip}" =~ ^100\. ]]; then
    log "[tailscale] authenticated; tailscale_ip=${ip}"
    return 0
  fi

  echo
  echo "=================================================================="
  echo "[tailscale] authentication not complete"
  echo "=================================================================="
  echo "Tailscale did not return a 100.x IP, so the installer will stop here."
  echo
  echo "Current tailscale status:"
  echo "${status_output}"
  echo
  echo "Recovery:"
  echo "  sudo tailscale up --ssh --hostname=${TAILSCALE_HOSTNAME}"
  echo
  echo "Wait for the terminal to print 'Success.' after browser authentication."
  echo "Then verify:"
  echo "  tailscale status"
  echo "  tailscale ip -4"
  echo
  echo "After tailscale ip -4 returns a 100.x address, rerun:"
  echo "  cd ${SCRIPT_DIR}"
  echo "  ./install.sh"
  echo "and resume the saved install state."
  echo
  return 1
}

install_tailscale_if_requested() {
  [[ "${INSTALL_TAILSCALE_VALUE}" == "true" ]] || return 0
  [[ "${STEP_TAILSCALE:-}" == "done" ]] && return 0
  log "[tailscale] installing tailscale"
  wait_for_apt_lock 300
  curl -fsSL https://tailscale.com/install.sh | sh
  sudo systemctl enable --now tailscaled || true

  local cmd=(sudo tailscale up --hostname "${TAILSCALE_HOSTNAME}" --ssh)
  echo
  echo "=================================================================="
  echo "[tailscale] authentication"
  echo "=================================================================="
  echo "The next command may print a login URL. Open it on your laptop and authenticate."
  echo "Do not continue until the Pi terminal prints: Success."
  echo
  log "[tailscale] running: ${cmd[*]}"
  "${cmd[@]}" || true

  if ! verify_tailscale_authenticated; then
    die "Tailscale authentication did not complete; rerun the installer after Tailscale is authenticated."
  fi

  mark_step_done TAILSCALE
}

configure_field_ap_if_requested() {
  [[ "${CONFIGURE_AP_VALUE:-true}" == "true" ]] || return 0
  [[ "${STEP_FIELD_AP:-}" == "done" ]] && return 0
  local ssid="NEREUS ${SYSTEM_ID_VALUE}"
  local password="nereus-vision"

  log "[ap] configuring wlan0 FieldCam-AP ssid=${ssid}"
  sudo rfkill unblock wifi || true
  sudo nmcli radio wifi on || true
  sudo nmcli connection delete FieldCam-AP >/dev/null 2>&1 || true
  sudo nmcli connection add type wifi ifname wlan0 con-name FieldCam-AP autoconnect yes ssid "${ssid}"
  sudo nmcli connection modify FieldCam-AP \
    802-11-wireless.mode ap \
    802-11-wireless.band bg \
    ipv4.method shared \
    ipv6.method disabled \
    wifi-sec.key-mgmt wpa-psk \
    wifi-sec.psk "${password}"
  sudo nmcli connection up FieldCam-AP || true
  nmcli device status || true
  save_state_var "FIELD_AP_SSID" "${ssid}"
  mark_step_done FIELD_AP
}

start_services_if_requested() {
  [[ "${STEP_START_SERVICES:-}" == "done" ]] && return 0
  if [[ "${START_SERVICES_VALUE}" == "true" ]]; then
    log "[agent] starting nereus-agent.service"
    sudo systemctl restart nereus-agent
    log "[fieldcam] restarting fieldcam.service"
    sudo systemctl restart fieldcam
  fi
  mark_step_done START_SERVICES
}

run_validation() {
  [[ "${STEP_VALIDATE:-}" == "done" ]] && return 0
  log "[check] git version: $(git --version || true)"
  log "[check] repo path: ${REPO_DIR_VALUE}"
  log "[check] repo branch: ${REPO_BRANCH_VALUE}"
  [[ -d "${REPO_DIR_VALUE}/device/system_agent/.venv" ]] || die "system_agent venv missing"
  [[ -d "${REPO_DIR_VALUE}/fieldcam_app/.venv" ]] || die "fieldcam_app venv missing"
  [[ -f /etc/nereus/nereus-agent.env ]] || die "nereus-agent.env missing"
  [[ -f /etc/systemd/system/nereus-agent.service ]] || die "nereus-agent.service missing"
  [[ -f /etc/systemd/system/fieldcam.service ]] || die "fieldcam.service missing"

  # shellcheck disable=SC1091
  source "${REPO_DIR_VALUE}/device/system_agent/.venv/bin/activate"
  python - <<'PY'
import board
import busio
import adafruit_bme280
print("BME280 Python imports OK")
PY
  mapfile -t py_files < <(find "${REPO_DIR_VALUE}/device/system_agent/src/system_agent" -maxdepth 1 -name '*.py' | sort)
  if [[ ${#py_files[@]} -gt 0 ]]; then
    python -m py_compile "${py_files[@]}"
    log "[check] py_compile passed for system_agent modules"
  fi
  if grep -Rni "WITTYPI_SCHEDULE_STATE_PATH\|hardware_name() == "wittypi"\|from system_agent import wittypi_controller" "${REPO_DIR_VALUE}/device/system_agent/src/system_agent" >/tmp/nereus_witty_refs.txt 2>/dev/null; then
    cat /tmp/nereus_witty_refs.txt
    die "Runtime Witty Pi references found in active system_agent code"
  fi
  deactivate

  sudo systemctl status nereus-agent --no-pager || true
  sudo systemctl status fieldcam --no-pager || true
  mark_step_done VALIDATE
}

run_manual_lte_checkpoint() {
  [[ "${STEP_LTE_MANUAL:-}" == "done" ]] && return 0
  if prompt_yes_no_default_yes "Show LTE bring-up manual checkpoint now?"; then
    manual_checkpoint "[manual] LTE modem bring-up" "lte_qmi.md" || true
  fi
  mark_step_done LTE_MANUAL
}

run_manual_camera_checkpoint() {
  [[ "${STEP_CAMERA_MANUAL:-}" == "done" ]] && return 0
  if prompt_yes_no_default_yes "Show camera and hardware validation checkpoint now?"; then
    manual_checkpoint "[manual] Camera and hardware validation" "camera_validation.md" || true
  fi
  mark_step_done CAMERA_MANUAL
}

run_manual_bme280_checkpoint() {
  [[ "${STEP_BME280_MANUAL:-}" == "done" ]] && return 0
  if prompt_yes_no_default_yes "Show BME280 / I2C validation checkpoint now?"; then
    manual_checkpoint "[manual] BME280 / I2C validation" "bme280_i2c.md" || true
  fi
  mark_step_done BME280_MANUAL
}

run_manual_lifepo4wered_checkpoint() {
  [[ "${INSTALL_LIFEPO4WERED_VALUE}" == "true" ]] || return 0
  [[ "${STEP_LIFEPO4WERED_MANUAL:-}" == "done" ]] && return 0
  if prompt_yes_no_default_yes "Show LiFePO4wered/Pi+ validation checkpoint now?"; then
    manual_checkpoint "[manual] LiFePO4wered/Pi+ validation" "lifepo4wered_pi.md" || true
  fi
  mark_step_done LIFEPO4WERED_MANUAL
}

run_manual_external_sd_checkpoint() {
  [[ "${STEP_EXTERNAL_SD_MANUAL:-}" == "done" ]] && return 0
  if prompt_yes_no_default_yes "Show optional external SD validation checkpoint now?"; then
    manual_checkpoint "[manual] External SD validation" "external_sd.md" || true
  fi
  mark_step_done EXTERNAL_SD_MANUAL
}

run_manual_ap_checkpoint() {
  [[ "${STEP_AP_MANUAL:-}" == "done" ]] && return 0
  if prompt_yes_no_default_yes "Show wlan0 AP validation checkpoint now?"; then
    manual_checkpoint "[manual] wlan0 AP validation" "ap_mode.md" || true
  fi
  mark_step_done AP_MANUAL
}

print_final_summary() {
  cat <<EOF

==================================================================
Install summary
==================================================================
Hostname:                    ${HOSTNAME_VALUE}
Tailscale hostname:          ${TAILSCALE_HOSTNAME}
SYSTEM_ID:                   ${SYSTEM_ID_VALUE}
DEVICE_ID:                   ${DEVICE_ID_VALUE}
API base:                    ${API_BASE_VALUE}
Repo directory:              ${REPO_DIR_VALUE}
Repo branch:                 ${REPO_BRANCH_VALUE}
Power hardware selected:     LiFePO4wered/Pi+
Enable power controller:     ${ENABLE_POWER_CONTROLLER_VALUE}
Power backend:               lifepo4wered only
Install LiFePO4wered/Pi+:    ${INSTALL_LIFEPO4WERED_VALUE}
Install Tailscale:           ${INSTALL_TAILSCALE_VALUE}
Tailscale SSH:               ${ENABLE_TAILSCALE_SSH_VALUE}
Install fieldcam_app:        true
Health monitoring:           true
BME280 internal env:         true
LTE / ModemManager:          installed/enabled
LTE modem IMEI:              ${MODEM_IMEI_VALUE:-unknown}
SIM ICCID:                   ${SIM_ICCID_VALUE:-unknown}
Cellular operator:           ${CELLULAR_OPERATOR_NAME_VALUE:-unknown} (${CELLULAR_OPERATOR_ID_VALUE:-unknown})
Device identity file:        /etc/nereus/device_identity.json
Prototype sudo mode:        pi NOPASSWD:ALL
Obsolete sudoers rules:      removed if present
External media storage:      enabled
External media mount point:  /mnt/nereus-media
Transient image dir:         /var/tmp/nereus-transient
Field AP SSID:               ${FIELD_AP_SSID:-NEREUS ${SYSTEM_ID_VALUE}}

State file:
  ${STATE_FILE}

Manual docs:
  ${MANUAL_DIR}

Useful commands:
  cd ${REPO_DIR_VALUE} && git branch --show-current
  sudo systemctl status nereus-agent --no-pager
  sudo tail -f /var/log/nereus/agent.log
  sudo systemctl status fieldcam --no-pager
  tailscale status
  nmcli device status
  mmcli -L
  mmcli -m 0
  mmcli -i 0
  sudo cat /etc/nereus/device_identity.json
  ip a show wwan0
  i2cdetect -y 1
  lifepo4wered-cli get
EOF
}

main() {
  maybe_resume_existing_state
  save_state_var "INSTALLER_VERSION" "4.9"

  require_sudo
  setup_prototype_passwordless_sudo
  check_platform
  check_network

  preflight_questions
  apply_hostname
  set_utc_timezone
  ensure_private_repo_access
  install_base_packages
  setup_lte_userland
  collect_lte_identity
  enable_i2c_if_possible
  clone_or_update_repo
  install_lifepo4wered_if_selected
  verify_lifepo4wered_hard_gate
  install_system_agent
  install_fieldcam_required
  install_tailscale_if_requested
  verify_lte_end_to_end
  verify_gps_alive_nonblocking
  configure_field_ap_if_requested
  start_services_if_requested
  run_validation
  run_manual_lte_checkpoint
  run_manual_camera_checkpoint
  run_manual_bme280_checkpoint
  run_manual_lifepo4wered_checkpoint
  run_manual_external_sd_checkpoint
  run_manual_ap_checkpoint
  print_final_summary
}

main "$@"
