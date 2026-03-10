#!/usr/bin/env bash
# =============================================================================
# pds.sh — Interactive entry-point for Podman Dev Stacks (install / remove)
# =============================================================================
# Usage:
#   bash pds.sh                        — interactive menu
#   bash pds.sh --remove               — enter remove mode directly
#   bash pds.sh --categories databases — filter to specific categories
#   bash pds.sh --help                 — show usage
#
# Piped usage (curl | bash):
#   curl ... | bash -s --              — interactive menu (if TTY available)
#   curl ... | bash -s -- --remove     — removes all images without prompts
#   Falls back to non-interactive install.sh if no TTY is available.
# =============================================================================

set -euo pipefail

# ── Bash version guard (namerefs require 4.3+) ───────────────────────────────
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )); then
  echo "[ERROR] pds.sh requires bash >= 4.3. macOS users: brew install bash" >&2
  exit 1
fi

# ── Safe PATH ─────────────────────────────────────────────────────────────────
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
log()     { printf '%b%s\n' "${CYAN}${BOLD}[INFO]${RESET}  " "$*" >&2; }
success() { printf '%b%s\n' "${GREEN}${BOLD}[OK]${RESET}    " "$*" >&2; }
warn()    { printf '%b%s\n' "${YELLOW}${BOLD}[WARN]${RESET}  " "$*" >&2; }
error()   { printf '%b%s\n' "${RED}${BOLD}[ERROR]${RESET} " "$*" >&2; }

section() {
  echo ""
  echo -e "${BOLD}━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ── Script directory ──────────────────────────────────────────────────────────
# When piped (curl | bash), BASH_SOURCE[0] is empty — SCRIPT_DIR stays empty
# and the non-interactive install path downloads install.sh via curl instead.
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR=""
fi

REPO_URL="https://raw.githubusercontent.com/Rzemieslnik-Programowania/podman-dev-stacks/main"

# ── Image registry ────────────────────────────────────────────────────────────
# Format: "image:tag|Human Label"
declare -a IMAGES_DATABASES=(
  "docker.io/postgres:16|PostgreSQL 16"
  "docker.io/mysql:8|MySQL 8"
  "docker.io/mariadb:11|MariaDB 11"
  "docker.io/mongo:7|MongoDB 7"
  "docker.io/redis:7|Redis 7"
  "docker.io/elasticsearch:8.12.0|Elasticsearch 8"
  "docker.io/influxdb:2|InfluxDB 2"
  "docker.io/neo4j:5|Neo4j 5"
  "docker.io/couchdb:3|CouchDB 3"
)

declare -a IMAGES_BROKERS=(
  "docker.io/rabbitmq:3-management|RabbitMQ 3 + Management UI"
  "docker.io/confluentinc/cp-zookeeper:latest|Confluent Zookeeper"
  "docker.io/confluentinc/cp-kafka:latest|Confluent Kafka"
  "docker.io/nats:latest|NATS"
)

declare -a IMAGES_WEBSERVERS=(
  "docker.io/nginx:alpine|NGINX Alpine"
  "docker.io/caddy:latest|Caddy"
  "docker.io/traefik:v3|Traefik v3"
  "docker.io/haproxy:alpine|HAProxy Alpine"
)

declare -a IMAGES_DEVTOOLS=(
  "docker.io/mailhog/mailhog:latest|MailHog"
  "docker.io/minio/minio:latest|MinIO"
  "docker.io/localstack/localstack:latest|LocalStack"
  "docker.io/wiremock/wiremock:latest|WireMock"
  "docker.io/verdaccio/verdaccio:latest|Verdaccio"
)

declare -a IMAGES_OBSERVABILITY=(
  "docker.io/grafana/grafana:latest|Grafana"
  "docker.io/prom/prometheus:latest|Prometheus"
  "docker.io/jaegertracing/all-in-one:latest|Jaeger"
  "docker.io/openzipkin/zipkin:latest|Zipkin"
  "docker.io/grafana/loki:latest|Loki"
  "docker.io/kibana:8.12.0|Kibana 8"
)

declare -a IMAGES_AUTH=(
  "docker.io/keycloak/keycloak:latest|Keycloak"
  "docker.io/dexidp/dex:latest|Dex"
  "docker.io/hashicorp/vault:latest|Vault"
)

declare -a IMAGES_TESTING=(
  "docker.io/selenium/standalone-chrome:latest|Selenium Chrome"
  "docker.io/sonarsource/sonarqube:community|SonarQube Community"
)

declare -a IMAGES_CICD=(
  "docker.io/jenkins/jenkins:lts|Jenkins LTS"
  "docker.io/gitea/gitea:latest|Gitea"
  "docker.io/portainer/portainer-ce:latest|Portainer CE"
)

declare -a IMAGES_RUNTIMES=(
  "docker.io/node:lts|Node.js LTS"
  "docker.io/node:25|Node.js 25"
  "docker.io/python:3.13|Python 3.13"
  "docker.io/python:3.13-slim|Python 3.13 Slim"
  "docker.io/rust:latest|Rust latest"
  "docker.io/golang:1.23|Go 1.23"
  "docker.io/eclipse-temurin:21|Java 21 (Temurin)"
  "docker.io/php:8.3-fpm|PHP 8.3 FPM"
  "docker.io/ruby:3.3|Ruby 3.3"
  "mcr.microsoft.com/dotnet/sdk:8.0|.NET SDK 8"
)

# ── Category metadata ─────────────────────────────────────────────────────────
CATEGORY_NAMES=(databases brokers webservers devtools observability auth testing cicd runtimes)
CATEGORY_TITLES=(
  "Databases"
  "Message Brokers & Queues"
  "Web Servers & Proxies"
  "Dev Tools & Utilities"
  "Observability & Monitoring"
  "Auth & Identity"
  "Testing & QA"
  "CI/CD & Container Tooling"
  "Language Runtimes"
)
CATEGORY_KEYS=(d b w t o u q i r)

# ── Selection state ───────────────────────────────────────────────────────────
declare -A IMAGE_SELECTED

# Ordered list of all image refs (preserves display order)
ALL_IMAGE_REFS=()
# Map image ref -> label
declare -A IMAGE_LABELS

# Populated by get_selected_images(); used to pass array results without subshells
declare -a SELECTED_LIST=()
# Populated by show_force_remove_menu(); images confirmed for force removal
declare -a FORCE_REMOVE_LIST=()

# Visible images for interactive mode (filtered by install/remove state)
VISIBLE_IMAGE_REFS=()
declare -A IMAGE_VISIBLE
declare -A IMAGE_VISIBLE_CATS

_build_image_index() {
  ALL_IMAGE_REFS=()
  local _bii_cat _bii_arr_name _bii_entry _bii_image _bii_label
  for _bii_cat in "${CATEGORY_NAMES[@]}"; do
    _bii_arr_name="IMAGES_${_bii_cat^^}"
    local -n _bii_arr="$_bii_arr_name"
    for _bii_entry in "${_bii_arr[@]}"; do
      _bii_image="${_bii_entry%%|*}"
      _bii_label="${_bii_entry##*|}"
      ALL_IMAGE_REFS+=("$_bii_image")
      IMAGE_LABELS["$_bii_image"]="$_bii_label"
    done
    unset -n _bii_arr
  done
}

build_visible_list() {
  VISIBLE_IMAGE_REFS=()
  IMAGE_VISIBLE=()
  IMAGE_VISIBLE_CATS=()

  # Query local Podman store once (avoids N forks of `podman image exists`)
  local -A _bvl_local_images=()
  local _bvl_line
  while IFS= read -r _bvl_line; do
    [[ -n "$_bvl_line" ]] && _bvl_local_images["$_bvl_line"]=1
  done < <(podman images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null)

  # Determine which categories are active
  local -a _bvl_active_cats=()
  if [[ -n "$CATEGORIES_FILTER" ]]; then
    local -a _bvl_filter_cats
    IFS=',' read -ra _bvl_filter_cats <<< "$CATEGORIES_FILTER"
    local _bvl_f _bvl_c
    for _bvl_f in "${_bvl_filter_cats[@]}"; do
      _bvl_f="${_bvl_f#"${_bvl_f%%[! ]*}"}"
      _bvl_f="${_bvl_f%"${_bvl_f##*[! ]}"}"
      for _bvl_c in "${CATEGORY_NAMES[@]}"; do
        if [[ "$_bvl_f" == "$_bvl_c" ]]; then
          _bvl_active_cats+=("$_bvl_c")
          break
        fi
      done
    done
  else
    _bvl_active_cats=("${CATEGORY_NAMES[@]}")
  fi

  local _bvl_cat _bvl_arr_name _bvl_entry _bvl_image _bvl_exists _bvl_canonical _bvl_path
  for _bvl_cat in "${_bvl_active_cats[@]}"; do
    _bvl_arr_name="IMAGES_${_bvl_cat^^}"
    local -n _bvl_arr="$_bvl_arr_name"
    for _bvl_entry in "${_bvl_arr[@]}"; do
      _bvl_image="${_bvl_entry%%|*}"
      # Normalize docker.io short names to canonical form (docker.io/X:T → docker.io/library/X:T)
      # so they match podman's output format
      _bvl_canonical="$_bvl_image"
      if [[ "$_bvl_image" == docker.io/* ]]; then
        _bvl_path="${_bvl_image#docker.io/}"
        if [[ "$_bvl_path" != */* ]]; then
          _bvl_canonical="docker.io/library/${_bvl_path}"
        fi
      fi
      _bvl_exists=false
      if [[ -v _bvl_local_images["$_bvl_canonical"] ]] || [[ -v _bvl_local_images["$_bvl_image"] ]]; then
        _bvl_exists=true
      fi
      # Install mode: show images NOT present locally
      # Remove mode: show images present locally
      if [[ "$MODE" == "install" && "$_bvl_exists" == false ]] ||
         [[ "$MODE" == "remove" && "$_bvl_exists" == true ]]; then
        VISIBLE_IMAGE_REFS+=("$_bvl_image")
        IMAGE_VISIBLE["$_bvl_image"]=1
        IMAGE_VISIBLE_CATS["$_bvl_cat"]=1
      fi
    done
    unset -n _bvl_arr
  done
}

init_selection() {
  _build_image_index
  local _is_ref
  for _is_ref in "${ALL_IMAGE_REFS[@]}"; do
    IMAGE_SELECTED["$_is_ref"]="0"
  done
}

_select_all_refs() {
  local _sar_ref
  for _sar_ref in "${ALL_IMAGE_REFS[@]}"; do
    IMAGE_SELECTED["$_sar_ref"]="1"
  done
}

select_all() {
  local _sa_ref
  for _sa_ref in "${VISIBLE_IMAGE_REFS[@]}"; do
    IMAGE_SELECTED["$_sa_ref"]="1"
  done
}

unselect_all() {
  local _ua_ref
  for _ua_ref in "${ALL_IMAGE_REFS[@]}"; do
    IMAGE_SELECTED["$_ua_ref"]="0"
  done
}

toggle_image() {
  local ref="$1"
  if [[ "${IMAGE_SELECTED[$ref]}" == "1" ]]; then
    IMAGE_SELECTED["$ref"]="0"
  else
    IMAGE_SELECTED["$ref"]="1"
  fi
}

toggle_category() {
  local _tc_cat="$1"
  local _tc_arr_name="IMAGES_${_tc_cat^^}"
  local -n _tc_arr="$_tc_arr_name"

  local _tc_all_selected=true _tc_entry _tc_image _tc_has_visible=false
  for _tc_entry in "${_tc_arr[@]}"; do
    _tc_image="${_tc_entry%%|*}"
    [[ -v IMAGE_VISIBLE["$_tc_image"] ]] || continue
    _tc_has_visible=true
    if [[ "${IMAGE_SELECTED[$_tc_image]}" == "0" ]]; then
      _tc_all_selected=false
      break
    fi
  done

  if [[ "$_tc_has_visible" == false ]]; then
    unset -n _tc_arr
    return
  fi

  local _tc_new_val="1"
  if [[ "$_tc_all_selected" == true ]]; then
    _tc_new_val="0"
  fi

  for _tc_entry in "${_tc_arr[@]}"; do
    _tc_image="${_tc_entry%%|*}"
    [[ -v IMAGE_VISIBLE["$_tc_image"] ]] || continue
    IMAGE_SELECTED["$_tc_image"]="$_tc_new_val"
  done
  unset -n _tc_arr
}

count_selected() {
  local _cs_ref
  local count=0
  for _cs_ref in "${VISIBLE_IMAGE_REFS[@]}"; do
    if [[ "${IMAGE_SELECTED[$_cs_ref]}" == "1" ]]; then
      ((count++)) || true
    fi
  done
  echo "$count"
}

get_selected_images() {
  SELECTED_LIST=()
  local _gsi_ref
  for _gsi_ref in "${VISIBLE_IMAGE_REFS[@]}"; do
    if [[ "${IMAGE_SELECTED[$_gsi_ref]}" == "1" ]]; then
      SELECTED_LIST+=("$_gsi_ref")
    fi
  done
}

get_all_selected_images() {
  SELECTED_LIST=()
  local _gasi_ref
  for _gasi_ref in "${ALL_IMAGE_REFS[@]}"; do
    if [[ "${IMAGE_SELECTED[$_gasi_ref]}" == "1" ]]; then
      SELECTED_LIST+=("$_gasi_ref")
    fi
  done
}

# ── Flags / defaults ─────────────────────────────────────────────────────────
INSTALL_DIR="${HOME}/podman-dev-stacks"
NO_PULL=false
NO_PATH=false
MODE=""
CATEGORIES_FILTER=""
INPUT_SRC=""  # resolved in main() via resolve_tty; set -u catches premature use

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: pds.sh [options]

Options:
  --dir <path>          Install directory (default: ~/podman-dev-stacks)
  --no-pull             Skip image pulling during install
  --no-path             Skip PATH setup during install
  --remove              Enter remove mode directly
  --categories <list>   Comma-separated category filter
                        (databases,brokers,webservers,devtools,observability,
                         auth,testing,cicd,runtimes)
  --help                Show this help and exit

Examples:
  pds.sh                                    # interactive menu
  pds.sh --remove                           # remove images interactively
  pds.sh --remove --categories databases    # remove only database images
  pds.sh --no-pull                          # install repo without pulling images

Piped usage (curl | bash):
  curl -fsSL .../pds.sh | bash              # interactive menu (if TTY available)
  curl -fsSL .../pds.sh | bash -s -- --remove  # removes all images
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      if [[ $# -lt 2 ]]; then
        error "--dir requires a path argument"
        exit 1
      fi
      INSTALL_DIR="$2"
      shift 2
      ;;
    --no-pull)
      NO_PULL=true
      shift
      ;;
    --no-path)
      NO_PATH=true
      shift
      ;;
    --remove)
      MODE="remove"
      shift
      ;;
    --categories)
      if [[ $# -lt 2 ]]; then
        error "--categories requires a comma-separated list"
        exit 1
      fi
      CATEGORIES_FILTER="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    -*)
      error "Unknown option: $1"
      usage >&2
      exit 1
      ;;
    *)
      error "Unknown argument: $1"
      usage >&2
      exit 1
      ;;
  esac
done

# Flag conflict: --remove + --no-pull
if [[ "$MODE" == "remove" && "$NO_PULL" == true ]]; then
  warn "--no-pull is irrelevant with --remove (ignoring --no-pull)"
  NO_PULL=false
fi

# ── Prerequisites ─────────────────────────────────────────────────────────────
check_prerequisites() {
  if ! command -v podman &>/dev/null; then
    error "podman is not installed. Please install it first."
    echo "" >&2
    echo "  Install guide:" >&2
    echo "    Ubuntu/Debian : sudo apt install podman" >&2
    echo "    Fedora/RHEL   : sudo dnf install podman" >&2
    echo "    macOS         : brew install podman" >&2
    exit 1
  fi
}

# ── TTY detection & input source ──────────────────────────────────────────────
# Sets INPUT_SRC and returns 0 when interactive mode is possible, 1 otherwise.
resolve_tty() {
  if [[ -t 0 ]]; then
    INPUT_SRC="/dev/stdin"
    return 0
  fi
  if [[ -c /dev/tty && -r /dev/tty ]]; then
    if exec 3</dev/tty 2>/dev/null; then
      exec 3>&-
      INPUT_SRC="/dev/tty"
      return 0
    fi
  fi
  return 1
}

# ── Category filter ───────────────────────────────────────────────────────────
apply_category_filter() {
  if [[ -z "$CATEGORIES_FILTER" ]]; then
    return
  fi

  local _acf_ref
  for _acf_ref in "${ALL_IMAGE_REFS[@]}"; do
    IMAGE_SELECTED["$_acf_ref"]="0"
  done

  local -a _acf_cats
  IFS=',' read -ra _acf_cats <<< "$CATEGORIES_FILTER"

  local _acf_found_any=false _acf_filter _acf_matched _acf_cat _acf_entry _acf_image
  for _acf_filter in "${_acf_cats[@]}"; do
    # Trim whitespace
    _acf_filter="${_acf_filter#"${_acf_filter%%[! ]*}"}"
    _acf_filter="${_acf_filter%"${_acf_filter##*[! ]}"}"
    _acf_matched=false
    for _acf_cat in "${CATEGORY_NAMES[@]}"; do
      if [[ "$_acf_filter" == "$_acf_cat" ]]; then
        _acf_matched=true
        _acf_found_any=true
        local _acf_arr_name="IMAGES_${_acf_cat^^}"
        local -n _acf_arr="$_acf_arr_name"
        for _acf_entry in "${_acf_arr[@]}"; do
          _acf_image="${_acf_entry%%|*}"
          IMAGE_SELECTED["$_acf_image"]="1"
        done
        unset -n _acf_arr
        break
      fi
    done
    if [[ "$_acf_matched" == false ]]; then
      warn "Unknown category in filter: $_acf_filter (ignoring)"
    fi
  done

  if [[ "$_acf_found_any" == false ]]; then
    warn "No valid categories in filter. All images remain unselected."
  fi
}

# ── Banner ────────────────────────────────────────────────────────────────────
show_banner() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║     Podman Dev Stacks — Interactive Manager       ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
}

# ── Main menu ─────────────────────────────────────────────────────────────────
show_main_menu() {
  echo ""
  echo -e "${BOLD}What would you like to do?${RESET}"
  echo ""
  echo "  [1] Install (pull images)"
  echo "  [2] Remove (delete images)"
  echo "  [3] Exit"
  echo ""

  local choice
  read -rp "Select action [1-3]: " choice < "$INPUT_SRC"
  case "$choice" in
    1) MODE="install" ;;
    2) MODE="remove" ;;
    3) echo "Bye!"; exit 0 ;;
    *) warn "Invalid choice: $choice"; MODE="" ;;
  esac
}

# ── Image selection menu ──────────────────────────────────────────────────────
show_image_selection_menu() {
  local _sim_mode_label="$1"

  while true; do
    local _sim_total="${#VISIBLE_IMAGE_REFS[@]}"
    local _sim_selected
    _sim_selected="$(count_selected)"

    echo ""
    echo -e "${BOLD}Select images to ${_sim_mode_label}${RESET}  (Selected: ${GREEN}${_sim_selected}/${_sim_total}${RESET})"
    echo ""

    local _sim_num=0 _sim_idx _sim_cat _sim_title _sim_key _sim_arr_name _sim_entry _sim_image _sim_label _sim_mark
    local -a _sim_visible_keys=()
    for _sim_idx in "${!CATEGORY_NAMES[@]}"; do
      _sim_cat="${CATEGORY_NAMES[$_sim_idx]}"
      _sim_title="${CATEGORY_TITLES[$_sim_idx]}"
      _sim_key="${CATEGORY_KEYS[$_sim_idx]}"
      _sim_arr_name="IMAGES_${_sim_cat^^}"
      local -n _sim_arr="$_sim_arr_name"

      if [[ ! -v IMAGE_VISIBLE_CATS["$_sim_cat"] ]]; then
        unset -n _sim_arr
        continue
      fi

      _sim_visible_keys+=("$_sim_key")
      echo -e "  ${BOLD}${_sim_title}${RESET}  (toggle: ${CYAN}${_sim_key}${RESET})"

      for _sim_entry in "${_sim_arr[@]}"; do
        _sim_image="${_sim_entry%%|*}"
        [[ -v IMAGE_VISIBLE["$_sim_image"] ]] || continue
        ((_sim_num++)) || true
        _sim_label="${_sim_entry##*|}"
        _sim_mark="[ ]"
        if [[ "${IMAGE_SELECTED[$_sim_image]}" == "1" ]]; then
          _sim_mark="${GREEN}[x]${RESET}"
        fi
        printf "    %b %2d) %-30s %s\n" "$_sim_mark" "$_sim_num" "$_sim_label" "$_sim_image"
      done
      unset -n _sim_arr
      echo ""
    done

    local _sim_keys_hint _sim_old_ifs="$IFS"
    IFS='/'
    _sim_keys_hint="${_sim_visible_keys[*]}"
    IFS="$_sim_old_ifs"
    echo -e "  Commands: ${CYAN}1-${_sim_total}${RESET} toggle | ${CYAN}a${RESET} select all | ${CYAN}n${RESET} unselect all | ${CYAN}${_sim_keys_hint}${RESET} toggle category | ${CYAN}c${RESET} confirm | ${CYAN}x${RESET} cancel"
    echo ""

    local _sim_input
    read -rp "  > " _sim_input < "$INPUT_SRC"

    case "$_sim_input" in
      a) select_all ;;
      n) unselect_all ;;
      c) return 0 ;;
      x) return 1 ;;
      d) toggle_category "databases" ;;
      b) toggle_category "brokers" ;;
      w) toggle_category "webservers" ;;
      t) toggle_category "devtools" ;;
      o) toggle_category "observability" ;;
      u) toggle_category "auth" ;;
      q) toggle_category "testing" ;;
      i) toggle_category "cicd" ;;
      r) toggle_category "runtimes" ;;
      *)
        if [[ "$_sim_input" =~ ^[0-9]+$ ]] && (( _sim_input >= 1 && _sim_input <= ${#VISIBLE_IMAGE_REFS[@]} )); then
          local _sim_ref="${VISIBLE_IMAGE_REFS[$((_sim_input - 1))]}"
          toggle_image "$_sim_ref"
        else
          warn "Invalid input: $_sim_input"
        fi
        ;;
    esac
  done
}

# ── Confirmation ──────────────────────────────────────────────────────────────
show_confirmation() {
  local mode_label="$1"

  get_selected_images
  local count="${#SELECTED_LIST[@]}"

  if [[ "$count" -eq 0 ]]; then
    warn "No images selected. Returning to menu."
    return 1
  fi

  echo ""
  echo -e "${BOLD}The following ${count} image(s) will be ${mode_label}:${RESET}"
  echo ""
  local _sc_ref
  for _sc_ref in "${SELECTED_LIST[@]}"; do
    echo "  - ${IMAGE_LABELS[$_sc_ref]} ($_sc_ref)"
  done
  echo ""

  local answer
  read -rp "Proceed? [Y/n]: " answer < "$INPUT_SRC"
  case "$answer" in
    ""|[Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# ── Force-remove menu (for in-use images) ─────────────────────────────────────
show_force_remove_menu() {
  local -n _frm_refs=$1

  if [[ "${#_frm_refs[@]}" -eq 0 ]]; then
    return 1
  fi

  local -A _frm_selected=()
  local _frm_ref
  for _frm_ref in "${_frm_refs[@]}"; do
    _frm_selected["$_frm_ref"]="1"
  done

  while true; do
    local _frm_total="${#_frm_refs[@]}"
    local _frm_count=0
    for _frm_ref in "${_frm_refs[@]}"; do
      if [[ "${_frm_selected[$_frm_ref]}" == "1" ]]; then
        ((_frm_count++)) || true
      fi
    done

    echo ""
    echo -e "${YELLOW}${BOLD}The following images are in use by running containers:${RESET}"
    echo -e "  (Selected: ${GREEN}${_frm_count}/${_frm_total}${RESET})"
    echo ""

    local _frm_num=0 _frm_mark _frm_containers
    for _frm_ref in "${_frm_refs[@]}"; do
      ((_frm_num++)) || true
      _frm_mark="[ ]"
      if [[ "${_frm_selected[$_frm_ref]}" == "1" ]]; then
        _frm_mark="${GREEN}[x]${RESET}"
      fi
      _frm_containers="$(check_image_in_use "$_frm_ref")"
      printf "  %b %d) %-30s %s\n" "$_frm_mark" "$_frm_num" "${IMAGE_LABELS[$_frm_ref]}" "$_frm_ref"
      echo -e "       ${YELLOW}Containers: ${_frm_containers}${RESET}"
    done
    echo ""
    echo -e "  Commands: ${CYAN}1-${_frm_total}${RESET} toggle | ${CYAN}a${RESET} select all | ${CYAN}n${RESET} unselect all | ${CYAN}c${RESET} confirm | ${CYAN}x${RESET} cancel"
    echo ""

    local _frm_input
    read -rp "  > " _frm_input < "$INPUT_SRC"

    case "$_frm_input" in
      a)
        for _frm_ref in "${_frm_refs[@]}"; do
          _frm_selected["$_frm_ref"]="1"
        done
        ;;
      n)
        for _frm_ref in "${_frm_refs[@]}"; do
          _frm_selected["$_frm_ref"]="0"
        done
        ;;
      c)
        local _frm_fcount=0
        for _frm_ref in "${_frm_refs[@]}"; do
          if [[ "${_frm_selected[$_frm_ref]}" == "1" ]]; then
            ((_frm_fcount++)) || true
          fi
        done

        if [[ "$_frm_fcount" -eq 0 ]]; then
          warn "No images selected for force removal."
          return 1
        fi

        echo ""
        echo -e "${RED}${BOLD}Force remove ${_frm_fcount} image(s)? This will stop dependent containers.${RESET}"
        local _frm_answer
        read -rp "Proceed? [y/N]: " _frm_answer < "$INPUT_SRC"
        case "$_frm_answer" in
          [Yy]|[Yy][Ee][Ss])
            FORCE_REMOVE_LIST=()
            for _frm_ref in "${_frm_refs[@]}"; do
              if [[ "${_frm_selected[$_frm_ref]}" == "1" ]]; then
                FORCE_REMOVE_LIST+=("$_frm_ref")
              fi
            done
            return 0
            ;;
          *)
            warn "Force removal cancelled."
            return 1
            ;;
        esac
        ;;
      x) return 1 ;;
      *)
        if [[ "$_frm_input" =~ ^[0-9]+$ ]] && (( _frm_input >= 1 && _frm_input <= ${#_frm_refs[@]} )); then
          _frm_ref="${_frm_refs[$((_frm_input - 1))]}"
          if [[ "${_frm_selected[$_frm_ref]}" == "1" ]]; then
            _frm_selected["$_frm_ref"]="0"
          else
            _frm_selected["$_frm_ref"]="1"
          fi
        else
          warn "Invalid input: $_frm_input"
        fi
        ;;
    esac
  done
}

# ── Helper functions ──────────────────────────────────────────────────────────
check_image_in_use() {
  local image="$1"
  local -a _ciu_names
  mapfile -t _ciu_names < <(podman ps --filter "ancestor=${image}" --format "{{.Names}}" 2>/dev/null)
  local IFS=', '
  echo "${_ciu_names[*]}"
}

pull_single_image() {
  local image="$1"
  local label="$2"

  echo -ne "  Pulling ${BOLD}${label}${RESET} (${image}) ... "

  if podman image exists "$image"; then
    echo -e "${YELLOW}already exists, skipping${RESET}"
    return 1  # skipped
  fi

  if podman pull "$image" > /dev/null 2>&1; then
    echo -e "${GREEN}done${RESET}"
    return 0  # pulled
  else
    echo -e "${RED}FAILED${RESET}"
    warn "Could not pull $image"
    return 2  # failed
  fi
}

remove_single_image() {
  local image="$1"
  local label="$2"

  echo -ne "  Removing ${BOLD}${label}${RESET} (${image}) ... "

  if ! podman image exists "$image"; then
    echo -e "${YELLOW}not present, skipping${RESET}"
    return 1  # not present
  fi

  local output
  if output="$(podman rmi "$image" 2>&1)"; then
    echo -e "${GREEN}removed${RESET}"
    return 0  # removed
  else
    if echo "$output" | grep -qi "image is in use\|image used by"; then
      echo -e "${YELLOW}in use${RESET}"
      return 2  # in use
    else
      echo -e "${RED}FAILED${RESET}"
      warn "Could not remove $image: $output"
      return 3  # other failure
    fi
  fi
}

# ── Run install.sh (local or remote) ─────────────────────────────────────────
run_install_sh() {
  if [[ -n "$SCRIPT_DIR" ]]; then
    bash "$SCRIPT_DIR/install.sh" "$@"
  else
    curl -fsSL "${REPO_URL}/install.sh" | bash -s -- "$@"
  fi
}

# ── Install action ────────────────────────────────────────────────────────────
do_install() {
  # Build install.sh flags — always pass --no-pull so we control pulling
  local install_args=("--no-pull")
  [[ "$INSTALL_DIR" != "${HOME}/podman-dev-stacks" ]] && install_args+=("--dir" "$INSTALL_DIR")
  [[ "$NO_PATH" == true ]] && install_args+=("--no-path")

  section "Setting up repository"
  log "Running install.sh for repo setup and PATH configuration..."
  run_install_sh "${install_args[@]}"

  if [[ "$NO_PULL" == true ]]; then
    log "Skipping image pull (--no-pull)."
    return
  fi

  section "Image Selection"

  build_visible_list
  if [[ "${#VISIBLE_IMAGE_REFS[@]}" -eq 0 ]]; then
    log "No images to install — all registry images are already present locally."
    return
  fi

  if ! show_image_selection_menu "install"; then
    log "Image selection cancelled."
    return
  fi

  if ! show_confirmation "installed (pulled)"; then
    return
  fi

  section "Pulling Images"

  local pulled=0
  local skipped=0
  local failed=0
  local _di_ref _di_label _di_rc

  for _di_ref in "${SELECTED_LIST[@]}"; do
    _di_label="${IMAGE_LABELS[$_di_ref]}"
    _di_rc=0
    pull_single_image "$_di_ref" "$_di_label" || _di_rc=$?
    case "$_di_rc" in
      0) ((pulled++)) || true ;;
      1) ((skipped++)) || true ;;
      2) ((failed++)) || true ;;
    esac
  done

  # Summary
  echo ""
  echo -e "${BOLD}━━━ Install Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${GREEN}Pulled:${RESET}  $pulled"
  echo -e "  ${YELLOW}Skipped:${RESET} $skipped (already present)"
  echo -e "  ${RED}Failed:${RESET}  $failed"
  echo ""

  if [[ "$failed" -gt 0 ]]; then
    warn "Some images failed — check your internet connection."
  else
    success "All selected images ready!"
  fi
}

# ── Remove action ─────────────────────────────────────────────────────────────
do_remove() {
  section "Image Selection (Remove)"

  build_visible_list
  if [[ "${#VISIBLE_IMAGE_REFS[@]}" -eq 0 ]]; then
    log "No installed images to remove."
    return
  fi

  if ! show_image_selection_menu "remove"; then
    log "Image selection cancelled."
    return
  fi

  if ! show_confirmation "removed"; then
    return
  fi

  section "Removing Images"

  local removed=0
  local skipped_not_present=0
  local skipped_in_use=0
  local failed=0
  local IN_USE_IMAGES=()
  local _dr_ref _dr_label _dr_rc

  for _dr_ref in "${SELECTED_LIST[@]}"; do
    _dr_label="${IMAGE_LABELS[$_dr_ref]}"
    _dr_rc=0
    remove_single_image "$_dr_ref" "$_dr_label" || _dr_rc=$?
    case "$_dr_rc" in
      0) ((removed++)) || true ;;
      1) ((skipped_not_present++)) || true ;;
      2) IN_USE_IMAGES+=("$_dr_ref"); ((skipped_in_use++)) || true ;;
      3) ((failed++)) || true ;;
    esac
  done

  # Handle in-use images
  if [[ "${#IN_USE_IMAGES[@]}" -gt 0 ]]; then
    FORCE_REMOVE_LIST=()
    if show_force_remove_menu IN_USE_IMAGES; then
      section "Force Removing In-Use Images"
      for _dr_ref in "${FORCE_REMOVE_LIST[@]}"; do
        _dr_label="${IMAGE_LABELS[$_dr_ref]}"
        echo -ne "  Force removing ${BOLD}${_dr_label}${RESET} (${_dr_ref}) ... "
        if podman rmi --force "$_dr_ref" > /dev/null 2>&1; then
          echo -e "${GREEN}removed${RESET}"
          ((removed++)) || true
          ((skipped_in_use--)) || true
        else
          echo -e "${RED}FAILED${RESET}"
          ((failed++)) || true
        fi
      done
    fi
  fi

  # Summary
  echo ""
  echo -e "${BOLD}━━━ Remove Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${GREEN}Removed:${RESET}         $removed"
  echo -e "  ${YELLOW}Not present:${RESET}     $skipped_not_present"
  echo -e "  ${YELLOW}Skipped (in use):${RESET} $skipped_in_use"
  echo -e "  ${RED}Failed:${RESET}          $failed"
  echo ""

  if [[ "$failed" -gt 0 ]]; then
    warn "Some images could not be removed."
  elif [[ "$removed" -gt 0 ]]; then
    success "Selected images removed!"
  fi
}

# ── Non-interactive remove ────────────────────────────────────────────────────
do_remove_noninteractive() {
  section "Removing Images (non-interactive)"

  get_all_selected_images
  local count="${#SELECTED_LIST[@]}"

  if [[ "$count" -eq 0 ]]; then
    warn "No images selected for removal."
    return
  fi

  log "Removing ${count} image(s)..."

  local removed=0
  local skipped_not_present=0
  local failed=0
  local _drn_ref _drn_label _drn_rc

  for _drn_ref in "${SELECTED_LIST[@]}"; do
    _drn_label="${IMAGE_LABELS[$_drn_ref]}"
    _drn_rc=0
    remove_single_image "$_drn_ref" "$_drn_label" || _drn_rc=$?
    case "$_drn_rc" in
      0) ((removed++)) || true ;;
      1) ((skipped_not_present++)) || true ;;
      2)
        # In-use: force-remove non-interactively
        echo -ne "  Force removing ${BOLD}${_drn_label}${RESET} (${_drn_ref}) ... "
        if podman rmi --force "$_drn_ref" > /dev/null 2>&1; then
          echo -e "${GREEN}removed${RESET}"
          ((removed++)) || true
        else
          echo -e "${RED}FAILED${RESET}"
          ((failed++)) || true
        fi
        ;;
      3)
        # Other failure — already reported by remove_single_image
        ((failed++)) || true
        ;;
    esac
  done

  echo ""
  echo -e "${BOLD}━━━ Remove Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${GREEN}Removed:${RESET}     $removed"
  echo -e "  ${YELLOW}Not present:${RESET} $skipped_not_present"
  echo -e "  ${RED}Failed:${RESET}      $failed"
  echo ""
}

# ── Entry point ───────────────────────────────────────────────────────────────
main() {
  show_banner
  check_prerequisites
  init_selection

  if ! resolve_tty; then
    _select_all_refs
    apply_category_filter
    if [[ "$MODE" == "remove" ]]; then
      do_remove_noninteractive
    else
      # Delegate to install.sh for backwards-compatible one-liner behavior
      local passthrough_args=()
      [[ "$INSTALL_DIR" != "${HOME}/podman-dev-stacks" ]] && passthrough_args+=("--dir" "$INSTALL_DIR")
      [[ "$NO_PULL" == true ]] && passthrough_args+=("--no-pull")
      [[ "$NO_PATH" == true ]] && passthrough_args+=("--no-path")
      log "Non-interactive mode detected. Delegating to install.sh..."
      run_install_sh "${passthrough_args[@]}"
    fi
    return
  fi
  readonly INPUT_SRC

  # Interactive mode
  if [[ "$MODE" == "remove" ]]; then
    do_remove
  elif [[ "$MODE" == "install" ]]; then
    do_install
  else
    # Main menu loop
    while true; do
      show_main_menu
      case "$MODE" in
        install)
          do_install
          # Reset selection for potential next action
          init_selection
          MODE=""
          ;;
        remove)
          do_remove
          init_selection
          MODE=""
          ;;
        "")
          # Invalid choice, loop again
          ;;
      esac
    done
  fi
}

main
