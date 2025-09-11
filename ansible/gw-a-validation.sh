#!/usr/bin/env bash
# Validate environment: OS (Amazon Linux 2023), services, stunnel config.
# Safe-ish defaults without -e to allow continuing after a failed check.
set -u -o pipefail
IFS=$'\n\t'

# -------- UI helpers --------
is_tty=0
if [ -t 1 ]; then
  is_tty=1
fi

# Colors (only if stdout is a TTY)
if [ "$is_tty" -eq 1 ]; then
  BOLD="$(printf '\033[1m')"
  DIM="$(printf '\033[2m')"
  RED="$(printf '\033[31m')"
  GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"
  BLUE="$(printf '\033[34m')"
  RESET="$(printf '\033[0m')"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

# Symbols (fallback to ASCII if locale/terminal can't show UTF-8)
tick="✓"
cross="✗"
# crude fallback if not a TTY
if [ "$is_tty" -ne 1 ]; then
  tick="OK"
  cross="X"
fi

# Result storage
declare -a RESULTS=()
PASS_COUNT=0
FAIL_COUNT=0

add_result() {
  local status="$1" label="$2" details="${3:-}"
  # Use real tabs as separators
  RESULTS+=("$status"$'\t'"$label"$'\t'"$details")
  if [ "$status" = "PASS" ]; then
    PASS_COUNT=$((PASS_COUNT+1))
  else
    FAIL_COUNT=$((FAIL_COUNT+1))
  fi
}


print_header() {
  printf "%s\n" "${BOLD}${BLUE}===== Environment Validation Report =====${RESET}"
}

print_footer() {
  printf "%s\n" "${BOLD}${BLUE}=========================================${RESET}"
  printf "%s\n" "$(printf '%sSummary:%s %s%d passed%s, %s%d failed%s\n' "$BOLD" "$RESET" "$GREEN" "$PASS_COUNT" "$RESET" "$RED" "$FAIL_COUNT" "$RESET")"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    printf "%s\n" "${YELLOW}One or more checks failed. Review details above.${RESET}"
  else
    printf "%s\n" "${GREEN}All checks passed!${RESET}"
  fi
}


print_results() {
  printf "\n%s\n" "${BOLD}Checks:${RESET}"
  printf "%s\n" "${DIM}---------------------------------------------------------${RESET}"
  for entry in "${RESULTS[@]}"; do
    # Split on real tabs
    IFS=$'\t' read -r status label details <<<"$entry"

    if [ "$status" = "PASS" ]; then
      printf "%b %s%s%s" "$GREEN$tick$RESET" "$BOLD" "$label" "$RESET"
      [ -n "$details" ] && printf " — %s\n" "$details" || printf "\n"
    else
      printf "%b %s%s%s" "$RED$cross$RESET" "$BOLD" "$label" "$RESET"
      [ -n "$details" ] && printf " — %s\n" "$details" || printf "\n"
    fi
  done
  printf "%s\n" "${DIM}---------------------------------------------------------${RESET}"
}



command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# -------- Checks --------

check_os() {
  local label="OS is Amazon Linux 2023 (platform:al2023)"
  local platform_id
  if [ ! -r /etc/os-release ]; then
    add_result "FAIL" "$label" "/etc/os-release not readable or missing"
    return
  fi
  # Use the exact pipeline you provided
  platform_id="$(grep ^PLATFORM_ID= /etc/os-release | cut -d= -f2 | tr -d '\"' || true)"
  if [ "$platform_id" = "platform:al2023" ]; then
    add_result "PASS" "$label" "Detected: $platform_id"
  else
    add_result "FAIL" "$label" "Detected: ${platform_id:-<empty>}"
  fi
}

service_exists() {
  # Best-effort detection of a unit's existence
  # Return 0 if service unit seems to exist, 1 otherwise.
  local svc="$1"
  # systemctl status returns non-zero for not-found; capture stderr quietly
  if systemctl status "${svc}.service" >/dev/null 2>&1; then
    return 0
  fi
  # Some units may not be loaded unless installed; try list-unit-files
  if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${svc}\.service"; then
    return 0
  fi
  return 1
}

check_service_active() {
  # $1=service name, $2=label (optional)
  local svc="$1"
  local label="${2:-Service '$svc' is active}"
  if ! command_exists systemctl; then
    add_result "FAIL" "$label" "systemctl not found"
    return
  fi

  if ! service_exists "$svc"; then
    add_result "FAIL" "$label" "Service unit '${svc}.service' not found"
    return
  fi

  # systemctl is-active returns: active|inactive|failed|activating|deactivating|unknown
  local status
  status="$(systemctl is-active "$svc" 2>/dev/null || true)"
  if [ "$status" = "active" ]; then
    add_result "PASS" "$label" "Status: active"
  else
    # Provide more context if available
    local substate=""
    substate="$(systemctl show "$svc" -p SubState --value 2>/dev/null || true)"
    if [ -n "$substate" ]; then
      add_result "FAIL" "$label" "Status: ${status:-<unknown>}, SubState: $substate"
    else
      add_result "FAIL" "$label" "Status: ${status:-<unknown>}"
    fi
  fi
}

check_stunnel_conf() {
  local label="Stunnel config exists and is non-empty"
  local p1="/etc/stunnel/stunnel.conf"
  local p2="/etc/stunnel5/stunnel.conf"

  if [ -e "$p1" ] && [ ! -f "$p1" ]; then
    add_result "FAIL" "$label" "$p1 exists but is not a regular file"
    return
  fi
  if [ -e "$p2" ] && [ ! -f "$p2" ]; then
    add_result "FAIL" "$label" "$p2 exists but is not a regular file"
    return
  fi

  if [ -s "$p1" ]; then
    add_result "PASS" "$label" "$p1 present and non-empty"
  elif [ -e "$p1" ] && [ ! -s "$p1" ]; then
    add_result "FAIL" "$label" "$p1 exists but is empty"
  elif [ -s "$p2" ]; then
    add_result "PASS" "$label" "$p2 present and non-empty"
  elif [ -e "$p2" ] && [ ! -s "$p2" ]; then
    add_result "FAIL" "$label" "$p2 exists but is empty"
  else
    add_result "FAIL" "$label" "Neither $p1 nor $p2 found"
  fi
}

check_cron_job() {
  local label="Cron job for check_stunnel.py exists"
  local expected="*/5 * * * * python3 /root/stunnel/check_stunnel.py >> /root/stunnel/check_stunnel.log 2>&1"

  # Try root's crontab first
  local cron_output=""
  if command_exists crontab; then
    cron_output="$(crontab -l 2>/dev/null || true)"
  fi

  # Also check system-wide cron file
  if [ -r /etc/crontab ]; then
    cron_output="${cron_output}"$'\n'"$(grep -vE '^\s*#' /etc/crontab || true)"
  fi

  # Look for the exact line
  if printf "%s\n" "$cron_output" | grep -Fxq "$expected"; then
    add_result "PASS" "$label" "Cron entry found"
  else
    add_result "FAIL" "$label" "Cron entry not found"
  fi
}


# -------- Run all checks --------
print_header

check_os
check_service_active "falcon-sensor" "falcon-sensor service is active"
check_service_active "amagent" "amagent service is active"
check_stunnel_conf
check_service_active "stunnel" "stunnel service is active"
check_cron_job

print_results
print_footer