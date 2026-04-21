#!/usr/bin/env bash

set -euo pipefail

# Resolve the directory that contains this script so we can load a local .env.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./ssh_connect.sh "ssh user@host"
  ./ssh_connect.sh "ssh -p 39300 user@host"
  ./ssh_connect.sh ssh -p 39300 user@host
  ./ssh_connect.sh --host host --user user [--port 22] [--password password]
  ./ssh_connect.sh ssh -p 39300 user@host --user override-user

Supported environment variables:
  SSH_HOST
  SSH_PORT
  SSH_USER
  SSH_PASSWORD

Precedence:
  explicit CLI args > parsed full ssh command > environment / .env
EOF
}

trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

# Load only the SSH_* keys we explicitly support from a local .env file.
# This avoids sourcing arbitrary shell content.
load_dotenv() {
  local env_file="$SCRIPT_DIR/.env"
  if [[ -f "$env_file" ]]; then
    local line
    local key
    local value
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="$(trim "$line")"
      [[ -n "$line" ]] || continue
      [[ "$line" == \#* ]] && continue
      [[ "$line" == *=* ]] || continue

      key="${line%%=*}"
      value="${line#*=}"
      key="$(trim "$key")"
      value="$(trim "$value")"

      if [[ "$value" =~ ^".*"$ ]] || [[ "$value" =~ ^'.*'$ ]]; then
        value="${value:1:${#value}-2}"
      fi

      case "$key" in
        SSH_HOST|SSH_PORT|SSH_USER|SSH_PASSWORD)
          if [[ -z "${!key:-}" ]]; then
            printf -v "$key" '%s' "$value"
            export "$key"
          fi
          ;;
      esac
    done < "$env_file"
  fi
}

# Ensure required flags are followed by a value.
require_value() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    printf 'Error: missing required value for %s\n' "$name" >&2
    exit 1
  fi
}

# Validate that the final port looks like a real TCP port.
validate_port() {
  local value="$1"
  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    printf 'Error: port must be a number, got: %s\n' "$value" >&2
    exit 1
  fi
  if (( value < 1 || value > 65535 )); then
    printf 'Error: port must be between 1 and 65535, got: %s\n' "$value" >&2
    exit 1
  fi
}

# Keep the accepted username format intentionally conservative.
validate_user() {
  local value="$1"
  if [[ ! "$value" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'Error: invalid SSH user: %s\n' "$value" >&2
    exit 1
  fi
}

# Accept a generic hostname / IPv4 / simple host:port-like token surface,
# but reject values that obviously look like misplaced flags.
validate_host() {
  local value="$1"
  if [[ "$value" == -* ]]; then
    printf 'Error: invalid SSH host: %s\n' "$value" >&2
    exit 1
  fi
  if [[ ! "$value" =~ ^[A-Za-z0-9._:-]+$ ]]; then
    printf 'Error: invalid SSH host: %s\n' "$value" >&2
    exit 1
  fi
}

# Parse common SSH command shapes such as:
#   ssh user@host
#   ssh -p 39300 user@host
# Unknown SSH flags are tolerated and skipped when possible.
parse_full_command_tokens() {
  local -a tokens=("$@")
  (( ${#tokens[@]} > 0 )) || return 0
  parsed_host=""
  parsed_port=""
  parsed_user=""
  parsed_target=""
  parsed_tokens_consumed=0

  if [[ "${tokens[0]}" != "ssh" ]]; then
    printf 'Error: full command mode expects a command starting with ssh\n' >&2
    exit 1
  fi

  local idx=1
  local token
  while (( idx < ${#tokens[@]} )); do
    token="${tokens[idx]}"
    case "$token" in
      -p)
        (( idx + 1 < ${#tokens[@]} )) || {
          printf 'Error: missing value after -p in SSH command\n' >&2
          exit 1
        }
        parsed_port="${tokens[idx + 1]}"
        idx=$((idx + 2))
        ;;
      -p*)
        parsed_port="${token#-p}"
        idx=$((idx + 1))
        ;;
      -l)
        (( idx + 1 < ${#tokens[@]} )) || {
          printf 'Error: missing value after -l in SSH command\n' >&2
          exit 1
        }
        parsed_user="${tokens[idx + 1]}"
        idx=$((idx + 2))
        ;;
      --)
        idx=$((idx + 1))
        break
        ;;
      -*)
        idx=$((idx + 1))
        if [[ "$token" =~ ^-[iJLoSbFwDEIcm]$ ]] && (( idx < ${#tokens[@]} )); then
          idx=$((idx + 1))
        fi
        ;;
      *)
        parsed_target="$token"
        idx=$((idx + 1))
        break
        ;;
    esac
  done

  parsed_tokens_consumed=$idx

  if [[ -n "$parsed_target" ]]; then
    if [[ "$parsed_target" == *@* ]]; then
      if [[ -z "$parsed_user" ]]; then
        parsed_user="${parsed_target%@*}"
      fi
      parsed_host="${parsed_target#*@}"
    else
      parsed_host="$parsed_target"
    fi
  fi
}

parse_full_command_string() {
  local command_string="$1"
  command_string="$(trim "$command_string")"
  [[ -n "$command_string" ]] || return 0

  local -a tokens=()
  read -r -a tokens <<< "$command_string"
  parse_full_command_tokens "${tokens[@]}"
}

load_dotenv

env_host="${SSH_HOST:-}"
env_port="${SSH_PORT:-}"
env_user="${SSH_USER:-}"
env_password="${SSH_PASSWORD:-}"

cli_host=""
cli_port=""
cli_user=""
cli_password=""
full_command=""
parsed_tokens_consumed=0

while (( $# > 0 )); do
  case "$1" in
    --host)
      require_value "$1" "${2:-}"
      cli_host="$2"
      shift 2
      ;;
    --port)
      require_value "$1" "${2:-}"
      cli_port="$2"
      shift 2
      ;;
    --user)
      require_value "$1" "${2:-}"
      cli_user="$2"
      shift 2
      ;;
    --password)
      require_value "$1" "${2:-}"
      cli_password="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ "$1" == "ssh" ]]; then
        current_tokens=("$@")
        parse_full_command_tokens "${current_tokens[@]}"
        shift "$parsed_tokens_consumed"
      elif [[ -z "$full_command" && "$1" == ssh* ]]; then
        full_command="$1"
        shift
      else
        printf 'Error: unrecognized or misplaced argument: %s\n\n' "$1" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

parsed_host=""
parsed_port=""
parsed_user=""
parsed_target=""

if [[ -n "$full_command" ]]; then
  parse_full_command_string "$full_command"
fi

final_host="$env_host"
final_port="${env_port:-22}"
final_user="$env_user"
final_password="$env_password"

if [[ -n "$parsed_host" ]]; then
  final_host="$parsed_host"
fi
if [[ -n "$parsed_port" ]]; then
  final_port="$parsed_port"
fi
if [[ -n "$parsed_user" ]]; then
  final_user="$parsed_user"
fi

if [[ -n "$cli_host" ]]; then
  final_host="$cli_host"
fi
if [[ -n "$cli_port" ]]; then
  final_port="$cli_port"
fi
if [[ -n "$cli_user" ]]; then
  final_user="$cli_user"
fi
if [[ -n "$cli_password" ]]; then
  final_password="$cli_password"
fi

final_host="$(trim "$final_host")"
final_port="$(trim "$final_port")"
final_user="$(trim "$final_user")"

if [[ -z "$final_host" && -z "$final_user" && -z "$full_command" && -z "$cli_host" && -z "$cli_user" ]]; then
  printf 'No SSH target provided.\n\n'
  usage
  exit 0
fi

require_value "host (--host / SSH_HOST / parsed ssh target)" "$final_host"
require_value "user (--user / SSH_USER / parsed ssh target)" "$final_user"

if [[ -z "$final_port" ]]; then
  final_port="22"
fi

validate_user "$final_user"
validate_host "$final_host"
validate_port "$final_port"

ssh_mode="interactive ssh"
if [[ -n "$final_password" ]]; then
  if command -v sshpass >/dev/null 2>&1; then
    ssh_mode="sshpass non-interactive login"
  else
    printf 'Notice: SSH_PASSWORD is set but sshpass is not installed.\n' >&2
    printf 'Install on macOS with: brew install hudochenkov/sshpass/sshpass\n' >&2
    printf 'Falling back to normal interactive ssh.\n' >&2
  fi
fi

printf 'Preparing SSH connection...\n'
printf '  Host: %s\n' "$final_host"
printf '  Port: %s\n' "$final_port"
printf '  User: %s\n' "$final_user"
printf '  Mode: %s\n' "$ssh_mode"

ssh_args=(ssh -p "$final_port" "${final_user}@${final_host}")

if [[ -n "$final_password" ]] && command -v sshpass >/dev/null 2>&1; then
  exec sshpass -p "$final_password" "${ssh_args[@]}"
fi

exec "${ssh_args[@]}"
