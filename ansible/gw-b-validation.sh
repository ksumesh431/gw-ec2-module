#!/usr/bin/env bash
# Validation for server 2: OS, CrowdStrike, Automox, crons, Observium, postfix package and logs
set -u -o pipefail
IFS=$'\n\t'

# -------- UI helpers --------
is_tty=0; [ -t 1 ] && is_tty=1
if [ "$is_tty" -eq 1 ]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"
  RED="$(printf '\033[31m')"; GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"; BLUE="$(printf '\033[34m')"
  RESET="$(printf '\033[0m')"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi
tick="✓"; cross="✗"; [ "$is_tty" -ne 1 ] && tick="OK" && cross="X"

# -------- Results aggregation --------
declare -a RESULTS=()
PASS_COUNT=0
FAIL_COUNT=0
add_result() {
  local status="$1" label="$2" details="${3:-}"
  RESULTS+=("$status"$'\t'"$label"$'\t'"$details")
  if [ "$status" = "PASS" ]; then PASS_COUNT=$((PASS_COUNT+1)); else FAIL_COUNT=$((FAIL_COUNT+1)); fi
}
print_header(){ printf "%s\n" "${BOLD}${BLUE}===== Environment Validation Report (Server 2) =====${RESET}"; }
print_footer(){
  printf "%s\n" "${BOLD}${BLUE}====================================================${RESET}"
  printf "%s\n" "$(printf '%sSummary:%s %s%d passed%s, %s%d failed%s\n' "$BOLD" "$RESET" "$GREEN" "$PASS_COUNT" "$RESET" "$RED" "$FAIL_COUNT" "$RESET")"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    printf "%s\n" "${YELLOW}One or more checks failed. Review details above.${RESET}"
  else
    printf "%s\n" "${GREEN}All checks passed!${RESET}"
  fi
}
print_results(){
  printf "\n%s\n" "${BOLD}Checks:${RESET}"
  printf "%s\n" "${DIM}---------------------------------------------------------${RESET}"
  for entry in "${RESULTS[@]}"; do
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
command_exists(){ command -v "$1" >/dev/null 2>&1; }

# -------- Common helpers --------
service_exists() {
  local svc="$1"
  if systemctl status "${svc}.service" >/dev/null 2>&1; then return 0; fi
  if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${svc}\.service"; then return 0; fi
  return 1
}
check_service_active(){
  local svc="$1" label="${2:-Service '$svc' is active}"
  if ! command_exists systemctl; then add_result "FAIL" "$label" "systemctl not found"; return; fi
  if ! service_exists "$svc"; then add_result "FAIL" "$label" "Service unit '${svc}.service' not found"; return; fi
  local status; status="$(systemctl is-active "$svc" 2>/dev/null || true)"
  if [ "$status" = "active" ]; then
    add_result "PASS" "$label" "Status: active"
  else
    local sub; sub="$(systemctl show "$svc" -p SubState --value 2>/dev/null || true)"
    [ -n "$sub" ] && add_result "FAIL" "$label" "Status: ${status:-<unknown>}, SubState: $sub" \
                  || add_result "FAIL" "$label" "Status: ${status:-<unknown>}"
  fi
}

# -------- Checks --------
check_os(){
  local label="OS is Amazon Linux 2023 (platform:al2023)"
  if [ ! -r /etc/os-release ]; then add_result "FAIL" "$label" "/etc/os-release not readable or missing"; return; fi
  local platform_id; platform_id="$(grep ^PLATFORM_ID= /etc/os-release | cut -d= -f2 | tr -d '\"' || true)"
  if [ "$platform_id" = "platform:al2023" ]; then
    add_result "PASS" "$label" "Detected: $platform_id"
  else
    add_result "FAIL" "$label" "Detected: ${platform_id:-<empty>}"
  fi
}

# Cron checks: search root crontab, /etc/crontab, and /etc/cron.d/*
collect_all_crons(){
  local out="" f
  if command_exists crontab; then out+="$(crontab -l 2>/dev/null || true)"; fi
  if [ -r /etc/crontab ]; then out+=$'\n'"$(cat /etc/crontab)"; fi
  if [ -d /etc/cron.d ]; then
    while IFS= read -r -d '' f; do
      out+=$'\n'"$(cat "$f" 2>/dev/null || true)"
    done < <(find /etc/cron.d -type f -readable -print0 2>/dev/null)
  fi
  printf "%s" "$out"
}

check_cron_lines(){
  local label="Required cron jobs exist"
  local -a expected_lines=(
    "50 6 * * 1-5 /root/ecs/bin/python3 /root/ecs_scaling_crons/scaling_ecs_Services.py >> /var/log/ecs_scaling.logs"
    "45 6 * * 1-5 /root/ecs/bin/python3 /root/ecs_scaling_crons/auto_scaling_group_update.py >> /var/log/ecs_scaling.logs"
    "0 19 * * 1-5 /root/ecs/bin/python3 /root/ecs_scaling_crons/scaling_ecs_Services.py >> /var/log/ecs_scaling.logs"
    "15 19 * * 5 sudo /root/ecs/bin/python3 /root/ecs_scaling_crons/auto_scaling_group_update.py >> /var/log/ecs_scaling.logs"
    "10 19 * * 1-5 /root/ecs/bin/python3 /root/ecs_scaling_crons/auto_scaling_group_update.py >> /var/log/ecs_scaling.logs"
    "30 13 * * 6 echo '' > /var/log/ecs_scaling.logs"
    "45 14 * * * /root/ecs/bin/python3 /root/automation/scripts/tomcat-container-logs-archival_to_s3.py &>> /var/log/efs_to_s3_move_logs.log"
  )
  local cron_blob; cron_blob="$(collect_all_crons)"
  local missing=()
  local line
  for line in "${expected_lines[@]}"; do
    if ! printf "%s\n" "$cron_blob" | grep -Fxq "$line"; then
      missing+=("$line")
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    add_result "PASS" "$label" "All required cron lines present"
  else
    add_result "FAIL" "$label" "Missing $((${#missing[@]})) cron line(s); first missing: ${missing[0]}"
  fi
}

check_observium_localhost(){
  local label="Observium login page is served on http://localhost/"
  if ! command_exists curl; then add_result "FAIL" "$label" "curl not found"; return; fi
  # Fetch page (follow redirects, 5s timeout)
  local body; body="$(curl -sS -m 5 -L http://localhost/ || true)"
  if [ -z "$body" ]; then
    add_result "FAIL" "$label" "Empty response or connection error"
    return
  fi
  # Look for indicative Observium markers
  if printf "%s" "$body" | grep -q "<title>Observium</title>" && \
     printf "%s" "$body" | grep -q "css/observium.css"; then
    add_result "PASS" "$label" "Observed Observium markers"
  else
    add_result "FAIL" "$label" "Did not find Observium markers (possibly default Apache page)"
  fi
}

check_postfix_installed(){
  local label="postfix package is installed"
  if command_exists rpm; then
    if rpm -q postfix >/dev/null 2>&1; then
      add_result "PASS" "$label" "rpm reports postfix installed"
      return
    fi
  fi
  if command_exists dnf; then
    if dnf list installed postfix >/dev/null 2>&1; then
      add_result "PASS" "$label" "dnf reports postfix installed"
      return
    fi
  fi
  add_result "FAIL" "$label" "postfix not installed (rpm/dnf)"
}

check_postfix_250ok(){
  local label="Postfix logs contain a recent '250 OK/Ok' delivery"
  if ! command_exists journalctl; then add_result "FAIL" "$label" "journalctl not found"; return; fi
  # Look through postfix unit logs (limit to a reasonable number of lines)
  local lines; lines="$(journalctl -u postfix --no-pager -n 5000 2>/dev/null || true)"
  if [ -z "$lines" ]; then
    add_result "FAIL" "$label" "No logs from postfix unit"
    return
  fi
  # Case-insensitive match for "250 ok" with optional spacing/casing
  local match; match="$(printf "%s" "$lines" | grep -Eim1 '250[[:space:]]*ok')" || true
  if [ -n "$match" ]; then
    add_result "PASS" "$label" "Found: ${match}"
  else
    add_result "FAIL" "$label" "No '250 OK/Ok' found in recent postfix logs"
  fi
}

# -------- Run all checks --------
print_header

check_os
check_service_active "falcon-sensor" "falcon-sensor service is active"
check_service_active "amagent" "amagent service is active"
check_cron_lines
check_observium_localhost
check_postfix_installed
check_postfix_250ok

print_results
print_footer
