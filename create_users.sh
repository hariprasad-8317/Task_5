# create_users.sh - Automates Linux user creation based on an input file
# Each line format: username; group1,group2
# See README for detailed explanation.

# Exit on error, undefined var, or pipefail
set -euo pipefail
IFS=$'\n\t'

INPUT_FILE="${1:-}"
PASSWORD_STORE_DIR="/var/secure"
PASSWORD_STORE_FILE="$PASSWORD_STORE_DIR/user_passwords.txt"
LOG_FILE="/var/log/user_management.log"

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 2
fi

log() {
  local level="$1"; shift
  local msg="$*"
  echo "[$(date --iso-8601=seconds)] [$level] $msg" | tee -a "$LOG_FILE"
}

prepare_files() {
  mkdir -p "$(dirname "$LOG_FILE")" "$PASSWORD_STORE_DIR"
  touch "$LOG_FILE" "$PASSWORD_STORE_FILE"
  chmod 600 "$LOG_FILE" "$PASSWORD_STORE_FILE"
}

generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 12
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12
  fi
}

process_user_line() {
  local line="$1"
  line="${line%%#*}"
  line="$(echo "$line" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')"
  [[ -z "$line" ]] && return 0

  if ! echo "$line" | grep -q ";"; then
    log "ERROR" "Malformed line: $line"
    return 0
  fi

  local username="$(echo "$line" | cut -d';' -f1 | tr -d '[:space:]')"
  local groups_part="$(echo "$line" | cut -d';' -f2- | tr -d '[:space:]')"
  IFS=',' read -r -a groups <<< "$groups_part"

  [[ -z "$username" ]] && { log "ERROR" "Empty username"; return 0; }

  for g in "${groups[@]}"; do
    [[ -z "$g" ]] && continue
    if ! getent group "$g" >/dev/null; then
      groupadd "$g" && log "INFO" "Created group $g" || log "ERROR" "Failed to create group $g"
    fi
  done

  if id -u "$username" >/dev/null 2>&1; then
    log "INFO" "User exists: $username"
    usermod -a -G "$(IFS=,; echo "${groups[*]}")" "$username"
  else
    useradd -m -s /bin/bash -G "$(IFS=,; echo "${groups[*]}")" "$username"
    log "SUCCESS" "Created user $username"
  fi

  local password
  password=$(generate_password)
  echo "$username:$password" | chpasswd && log "SUCCESS" "Password set for $username"
  echo "$username:$password" >> "$PASSWORD_STORE_FILE"
  chmod 600 "$PASSWORD_STORE_FILE"
}

main() {
  [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]] && { echo "Usage: $0 <input-file>"; exit 1; }
  prepare_files

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^# ]] && { log "INFO" "Skipping comment/blank line"; continue; }
    process_user_line "$line"
  done < "$INPUT_FILE"

  log "INFO" "Processing completed for file: $INPUT_FILE"
}

main
