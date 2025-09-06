#!/usr/bin/env bash
# DNS Leak Test Script using bash.ws API
# usage:   ./dnsleaktest.sh

set -euo pipefail  # safer scripting: exit on errors, unset vars, and pipe fails

# --- Styling ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'   # Reset color

# --- Globals ---
API_DOMAIN="bash.ws"
PING_SERVER="$API_DOMAIN"

# --- Helpers ---
echo_bold() { echo -e "${BOLD}${1}${NC}"; }
echo_error() { >&2 echo -e "${RED}${1}${NC}"; }
echo_success() { echo -e "${GREEN}${1}${NC}"; }

# --- Check required commands ---
require_command() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if ((${#missing[@]})); then
    echo_error "Missing required command(s): ${missing[*]}"
    exit 1
  fi
}

# --- Check connectivity ---
check_internet() {
  local max_attempts=3
  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    if ping -c 1 "$PING_SERVER" >/dev/null 2>&1; then
      echo_success "Internet connection is available."
      return 0
    fi
    echo_error "No internet connection (attempt $attempt/$max_attempts)."
    (( attempt < max_attempts )) && read -p "Press Enter to retry..."
  done
  echo_error "No internet connection after $max_attempts attempts. Exiting."
  exit 1
}

# --- Print results from API (handles JSON or TXT) ---
print_servers() {
  local type="$1"
  if (( jq_exists )); then
    jq -r ".[] | select(.type == \"$type\") |
      \"\(.ip)\(if .country_name and .country_name != \"\" then
        \" [\(.country_name)\(if .asn and .asn != \"\" then \" \(.asn)\" else \"\" end)]\"
      else \"\" end)\"" <<<"$result_json"
  else
    grep "$type" <<<"$result_txt" | while IFS='|' read -r ip _ country asn; do
      [[ -z "$ip" ]] && continue
      if [[ -n "$country" ]]; then
        [[ -n "$asn" ]] && echo "$ip [$country, $asn]" || echo "$ip [$country]"
      else
        echo "$ip"
      fi
    done
  fi
}

# --- Main script ---

echo "Running DNS Leak Test..."

# Check tools and network
require_command curl ping
echo "checking internet connection..."
check_internet
jq_exists=0
command -v jq >/dev/null 2>&1 && jq_exists=1

# Get unique test ID
echo "Getting unique test ID..."
id=$(curl --silent "https://${API_DOMAIN}/id")
echo "id: $id"

# Trigger DNS lookups by pinging unique hostnames
echo_bold "Sending DNS queries by pinging unique subdomains that the API can log..."
for i in $(seq 1 10); do
  ping -c 1 "${i}.${id}.${API_DOMAIN}" || true #>/dev/null 2>&1
done

# Get results (JSON if jq available, otherwise text)
if (( jq_exists )); then
  result_json=$(curl --silent "https://${API_DOMAIN}/dnsleak/test/${id}?json")
else
  result_txt=$(curl --silent "https://${API_DOMAIN}/dnsleak/test/${id}?txt")
fi

# Count DNS servers
dns_count=$(print_servers "dns" | wc -l | tr -d ' ')

# Show results
echo_bold "Your IP:"
print_servers "ip"

echo ""
if (( dns_count == 0 )); then
  echo_bold "No DNS servers found"
else
  echo_bold "You use $dns_count DNS server$([[ $dns_count -gt 1 ]] && echo 's'):"
  print_servers "dns"
fi

echo ""
echo_bold "Conclusion:"
print_servers "conclusion"

read -p "Press Enter to exit..."
exit 0
