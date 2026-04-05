#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
MANUAL_DIR="${SCRIPT_DIR}/manual_steps"

DEFAULT_API_BASE="https://nereus-vision-dev.onrender.com"
DEFAULT_REPO_SSH_URL="git@github.com:nickraymond/nereus-vision-dev.git"
DEFAULT_REPO_BRANCH="main"
DEFAULT_REPO_DIR="$HOME/code/nereus-vision-dev"
STATE_DIR="$HOME/.nereus-deploy"
STATE_FILE="${STATE_DIR}/install.env"

mkdir -p "${STATE_DIR}"

log() { printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { log "[error] $*"; exit 1; }

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

step_done() {
  local step="$1"
  [[ "${!1:-}" == "done" ]]
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
  API_BASE_VALUE="$(prompt_default 'API base URL' "${API_BASE_VALUE:-$DEFAULT_API_BASE}")"
  REPO_URL_VALUE="$(prompt_default 'Private repo SSH URL' "${REPO_URL_VALUE:-$DEFAULT_REPO_SSH_URL}")"
  REPO_BRANCH_VALUE="$(prompt_default 'Repo branch to install' "${REPO_BRANCH_VALUE:-$DEFAULT_REPO_BRANCH}")"
  REPO_DIR_VALUE="$(prompt_default 'Repo install directory' "${REPO_DIR_VALUE:-$DEFAULT_REPO_DIR}")"

  if prompt_yes_no_default_yes "Enable Witty Pi?"; then ENABLE_WITTYPI_VALUE="true"; else ENABLE_WITTYPI_VALUE="false"; fi
  if prompt_yes_no_default_yes "Install Witty Pi software if missing?"; then INSTALL_WITTYPI_VALUE="true"; else INSTALL_WITTYPI_VALUE="false"; fi
  if prompt_yes_no_default_yes "Install Tailscale?"; then INSTALL_TAILSCALE_VALUE="true"; else INSTALL_TAILSCALE_VALUE="false"; fi
  ENABLE_TAILSCALE_SSH_VALUE="true"
  if prompt_yes_no_default_yes "Install fieldcam_app and fieldcam.service?"; then INSTALL_FIELDCAM_VALUE="true"; else INSTALL_FIELDCAM_VALUE="false"; fi
  if prompt_yes_no_default_yes "Enable and start nereus-agent.service at end?"; then START_AGENT_SERVICE_VALUE="true"; else START_AGENT_SERVICE_VALUE="false"; fi

  for key in HOSTNAME_VALUE TAILSCALE_HOSTNAME SYSTEM_ID_VALUE DEVICE_ID_VALUE API_BASE_VALUE REPO_URL_VALUE REPO_BRANCH_VALUE REPO_DIR_VALUE ENABLE_WITTYPI_VALUE INSTALL_WITTYPI_VALUE INSTALL_TAILSCALE_VALUE ENABLE_TAILSCALE_SSH_VALUE INSTALL_FIELDCAM_VALUE START_AGENT_SERVICE_VALUE; do
    save_state_var "$key" "${!key}"
  done

  if ! prompt_yes_no_default_no "Have SYSTEM_ID and DEVICE_ID already been created in the backend?"; then
    die "Register SYSTEM_ID and DEVICE_ID in the backend first, then rerun the installer."
  fi

  if ! prompt_yes_no_default_yes "Continue with hostname ${HOSTNAME_VALUE}, SYSTEM_ID ${SYSTEM_ID_VALUE}, DEVICE_ID ${DEVICE_ID_VALUE}?"; then
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
  log "[apt] installing base packages"
  sudo apt-get update
  sudo apt-get install -y \
    git curl jq python3 python3-venv python3-pip \
    rpicam-apps python3-picamera2 minicom
  mark_step_done APT
}

clone_or_update_repo() {
  [[ "${STEP_REPO:-}" == "done" ]] && return 0
  mkdir -p "$(dirname "${REPO_DIR_VALUE}")"
  if [[ -d "${REPO_DIR_VALUE}/.git" ]]; then
    log "[repo] updating existing repo at ${REPO_DIR_VALUE}"
    git -C "${REPO_DIR_VALUE}" fetch origin
    git -C "${REPO_DIR_VALUE}" checkout "${REPO_BRANCH_VALUE}"
    git -C "${REPO_DIR_VALUE}" pull origin "${REPO_BRANCH_VALUE}"
  else
    log "[repo] cloning ${REPO_URL_VALUE} into ${REPO_DIR_VALUE}"
    git clone "${REPO_URL_VALUE}" "${REPO_DIR_VALUE}"
    git -C "${REPO_DIR_VALUE}" checkout "${REPO_BRANCH_VALUE}"
  fi
  mark_step_done REPO
}

install_system_agent() {
  [[ "${STEP_AGENT:-}" == "done" ]] && return 0
  local agent_dir="${REPO_DIR_VALUE}/device/system_agent"
  [[ -d "${agent_dir}" ]] || die "system_agent directory not found at ${agent_dir}"
  log "[agent] creating venv and installing requirements"
  python3 -m venv "${agent_dir}/.venv"
  source "${agent_dir}/.venv/bin/activate"
  pip install --upgrade pip wheel
  pip install -r "${agent_dir}/requirements.txt"
  deactivate

  log "[agent] creating directories"
  sudo mkdir -p /var/lib/nereus/images /var/log/nereus /etc/nereus
  sudo chown -R pi:pi /var/lib/nereus /var/log/nereus

  log "[agent] writing env file"
  sed \
    -e "s|__API_BASE__|${API_BASE_VALUE}|g" \
    -e "s|__SYSTEM_ID__|${SYSTEM_ID_VALUE}|g" \
    -e "s|__DEVICE_ID__|${DEVICE_ID_VALUE}|g" \
    -e "s|__ENABLE_WITTYPI__|${ENABLE_WITTYPI_VALUE}|g" \
    "${TEMPLATES_DIR}/nereus-agent.env.template" | sudo tee /etc/nereus/nereus-agent.env >/dev/null
  sudo chown root:root /etc/nereus/nereus-agent.env
  sudo chmod 600 /etc/nereus/nereus-agent.env

  log "[agent] writing systemd service"
  sed -e "s|__REPO_DIR__|${REPO_DIR_VALUE}|g" "${TEMPLATES_DIR}/nereus-agent.service.template" | sudo tee /etc/systemd/system/nereus-agent.service >/dev/null
  sudo rm -f /var/lib/nereus/system_config_cache*.json
  sudo systemctl daemon-reload
  sudo systemctl enable nereus-agent
  mark_step_done AGENT
}

install_fieldcam_if_requested() {
  [[ "${INSTALL_FIELDCAM_VALUE}" == "true" ]] || return 0
  [[ "${STEP_FIELDCAM:-}" == "done" ]] && return 0
  local app_dir="${REPO_DIR_VALUE}/fieldcam_app"
  [[ -d "${app_dir}" ]] || die "fieldcam_app directory not found at ${app_dir}"
  log "[fieldcam] creating venv and installing requirements"
  rm -rf "${app_dir}/.venv"
  python3 -m venv --system-site-packages "${app_dir}/.venv"
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

install_tailscale_if_requested() {
  [[ "${INSTALL_TAILSCALE_VALUE}" == "true" ]] || return 0
  [[ "${STEP_TAILSCALE:-}" == "done" ]] && return 0
  log "[tailscale] installing tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh
  local cmd=(sudo tailscale up --hostname "${TAILSCALE_HOSTNAME}" --ssh)
  log "[tailscale] running: ${cmd[*]}"
  "${cmd[@]}" || true
  if ! manual_checkpoint "[manual] Tailscale authentication" "tailscale_auth.md"; then
    die "Tailscale authentication did not complete successfully."
  fi
  mark_step_done TAILSCALE
}

start_services_if_requested() {
  [[ "${STEP_START_SERVICES:-}" == "done" ]] && return 0
  if [[ "${START_AGENT_SERVICE_VALUE}" == "true" ]]; then
    log "[agent] starting nereus-agent.service"
    sudo systemctl restart nereus-agent
  fi
  if [[ "${INSTALL_FIELDCAM_VALUE}" == "true" ]]; then
    log "[fieldcam] restarting fieldcam.service"
    sudo systemctl restart fieldcam
  fi
  mark_step_done START_SERVICES
}

run_validation() {
  [[ "${STEP_VALIDATE:-}" == "done" ]] && return 0
  log "[check] git version: $(git --version || true)"
  log "[check] repo path: ${REPO_DIR_VALUE}"
  [[ -d "${REPO_DIR_VALUE}/device/system_agent/.venv" ]] || die "system_agent venv missing"
  [[ -f /etc/nereus/nereus-agent.env ]] || die "nereus-agent.env missing"
  [[ -f /etc/systemd/system/nereus-agent.service ]] || die "nereus-agent.service missing"

  mapfile -t py_files < <(find "${REPO_DIR_VALUE}/device/system_agent/src/system_agent" -maxdepth 1 -name '*.py' | sort)
  if [[ ${#py_files[@]} -gt 0 ]]; then
    source "${REPO_DIR_VALUE}/device/system_agent/.venv/bin/activate"
    python -m py_compile "${py_files[@]}"
    deactivate
    log "[check] py_compile passed for system_agent modules"
  fi

  sudo systemctl status nereus-agent --no-pager || true
  if [[ "${INSTALL_FIELDCAM_VALUE}" == "true" ]]; then
    sudo systemctl status fieldcam --no-pager || true
  fi
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

install_wittypi_last() {
  [[ "${INSTALL_WITTYPI_VALUE}" == "true" ]] || return 0

  if [[ "${STEP_WITTYPI_POST_REBOOT:-}" == "done" ]]; then
    return 0
  fi

  if [[ "${STEP_WITTYPI_INSTALL:-}" != "done" ]]; then
    if [[ ! -d "$HOME/wittypi/.git" ]]; then
      log "[wittypi] cloning Witty Pi software"
      git clone https://github.com/uugear/Witty-Pi-4.git "$HOME/wittypi"
    else
      log "[wittypi] Witty Pi repo already present"
    fi
    [[ -f "$HOME/wittypi/Software/wittypi/utilities.sh" ]] || die "Expected Witty Pi files not found after clone"

    log "[wittypi] running installer last so reboot happens at the end"
    (cd "$HOME/wittypi/Software" && sudo ./install.sh)

    save_state_var "PENDING_REBOOT" "true"
    mark_step_done WITTYPI_INSTALL

    echo
    echo "=================================================================="
    echo "[wittypi] reboot required"
    echo "=================================================================="
    echo "Reboot now, then rerun ./install.sh."
    echo "The installer will resume at the Witty Pi manual configuration step."
    exit 0
  fi

  if [[ "${PENDING_REBOOT:-false}" == "true" ]]; then
    log "[wittypi] resuming after reboot"
    save_state_var "PENDING_REBOOT" "false"
  fi

  log "[wittypi] fixing Witty Pi log ownership"
  sudo chown pi:pi "$HOME/wittypi/Software/wittypi/wittyPi.log" "$HOME/wittypi/Software/wittypi/schedule.log" 2>/dev/null || true
  sudo chmod 664 "$HOME/wittypi/Software/wittypi/wittyPi.log" "$HOME/wittypi/Software/wittypi/schedule.log" 2>/dev/null || true

  if ! manual_checkpoint "[manual] Witty Pi configuration" "wittypi.md"; then
    die "Witty Pi manual configuration did not complete successfully."
  fi

  mark_step_done WITTYPI_POST_REBOOT
}

print_final_summary() {
  cat <<EOF

==================================================================
Install summary
==================================================================
Hostname:              ${HOSTNAME_VALUE}
Tailscale hostname:    ${TAILSCALE_HOSTNAME}
SYSTEM_ID:             ${SYSTEM_ID_VALUE}
DEVICE_ID:             ${DEVICE_ID_VALUE}
API base:              ${API_BASE_VALUE}
Repo directory:        ${REPO_DIR_VALUE}
Enable Witty Pi:       ${ENABLE_WITTYPI_VALUE}
Install Witty Pi:      ${INSTALL_WITTYPI_VALUE}
Install Tailscale:     ${INSTALL_TAILSCALE_VALUE}
Tailscale SSH:         ${ENABLE_TAILSCALE_SSH_VALUE}
Install fieldcam_app:  ${INSTALL_FIELDCAM_VALUE}

State file:
  ${STATE_FILE}

Manual docs:
  ${MANUAL_DIR}

Useful commands:
  sudo systemctl status nereus-agent --no-pager
  sudo tail -f /var/log/nereus/agent.log
  sudo systemctl status fieldcam --no-pager
  tailscale status
EOF
}

main() {
  maybe_resume_existing_state
  save_state_var "INSTALLER_VERSION" "2"

  require_sudo
  check_platform
  check_network

  preflight_questions
  apply_hostname
  set_utc_timezone
  ensure_private_repo_access
  install_base_packages
  clone_or_update_repo
  install_system_agent
  install_fieldcam_if_requested
  install_tailscale_if_requested
  start_services_if_requested
  run_validation
  run_manual_lte_checkpoint
  run_manual_camera_checkpoint
  install_wittypi_last
  print_final_summary
}

main "$@"
