#!/usr/bin/env bash
# =============================================================================
# Podman Dev Stacks — Installer
# =============================================================================
# Run this directly from GitHub:
#
#   curl -fsSL https://raw.githubusercontent.com/Rzemieslnik-Programowania/podman-dev-stacks/main/install.sh | bash
#
# Or with options:
#
#   curl -fsSL https://raw.githubusercontent.com/Rzemieslnik-Programowania/podman-dev-stacks/main/install.sh | bash -s -- --dir ~/.local/podman-dev-stacks --no-pull
#
# Options:
#   --dir <path>   Install location (default: ~/podman-dev-stacks)
#   --no-pull      Skip pulling Docker images after install
#   --no-path      Skip adding scripts to PATH in shell rc file
#   --help         Show this help
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log()     { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $*"; exit 1; }
step()    { echo -e "\n${BOLD}──── $* ────${RESET}"; }

# ── Defaults ──────────────────────────────────────────────────────────────────
INSTALL_DIR="${HOME}/podman-dev-stacks"
REPO_URL="https://github.com/Rzemieslnik-Programowania/podman-dev-stacks.git"
RAW_URL="https://raw.githubusercontent.com/Rzemieslnik-Programowania/podman-dev-stacks/main"
DO_PULL=true
DO_PATH=true

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)    INSTALL_DIR="$2"; shift 2 ;;
    --no-pull) DO_PULL=false; shift ;;
    --no-path) DO_PATH=false; shift ;;
    --help)
      echo ""
      echo "Usage: install.sh [options]"
      echo ""
      echo "  --dir <path>   Install location (default: ~/podman-dev-stacks)"
      echo "  --no-pull      Skip pulling images after install"
      echo "  --no-path      Skip adding scripts to PATH"
      echo "  --help         Show this message"
      echo ""
      exit 0
      ;;
    *) warn "Unknown option: $1"; shift ;;
  esac
done

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       Podman Dev Stacks — Installer              ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
log "Install dir : ${BOLD}${INSTALL_DIR}${RESET}"
log "Pull images : ${BOLD}${DO_PULL}${RESET}"
log "Update PATH : ${BOLD}${DO_PATH}${RESET}"

# ── Check prerequisites ───────────────────────────────────────────────────────
step "Checking prerequisites"

check_cmd() {
  if command -v "$1" &>/dev/null; then
    success "$1 found ($(command -v "$1"))"
  else
    error "$1 is not installed. Please install it first.
    
    Install guide:
      Ubuntu/Debian : sudo apt install $1
      Fedora/RHEL   : sudo dnf install $1
      macOS         : brew install $1"
  fi
}

check_cmd podman

# Check podman compose (plugin or standalone)
if podman compose version &>/dev/null 2>&1; then
  success "podman compose found"
elif command -v podman-compose &>/dev/null; then
  success "podman-compose found"
else
  warn "podman compose not found — stacks won't work without it."
  warn "Install: pip install podman-compose  OR  sudo apt install podman-compose"
fi

# git OR curl — we need at least one to download the repo
HAS_GIT=false
HAS_CURL=false
command -v git  &>/dev/null && HAS_GIT=true
command -v curl &>/dev/null && HAS_CURL=true

[[ "$HAS_GIT" == false && "$HAS_CURL" == false ]] && \
  error "Neither git nor curl is available. Install one of them first."

# ── Download repo ─────────────────────────────────────────────────────────────
step "Downloading Podman Dev Stacks"

if [[ -d "$INSTALL_DIR" ]]; then
  warn "Directory already exists: $INSTALL_DIR"
  if [[ -d "$INSTALL_DIR/.git" ]] && $HAS_GIT; then
    log "Pulling latest changes..."
    git -C "$INSTALL_DIR" pull --ff-only && success "Updated to latest" || warn "Could not update — continuing with existing version"
  else
    warn "Skipping download — using existing files."
  fi
else
  if $HAS_GIT; then
    log "Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    success "Cloned to $INSTALL_DIR"
  else
    # Fallback: download individual files via curl
    log "git not found — downloading files individually via curl..."
    _download_files
  fi
fi

# ── Fallback download via curl (no git) ───────────────────────────────────────
_download_files() {
  local dirs=(
    "scripts"
    "stacks/web-api"
    "stacks/microservices"
    "stacks/devops"
    "stacks/cloud-local"
    "stacks/data-ml"
    "runtimes/node"
    "runtimes/python"
    "runtimes/rust"
    "runtimes/go"
    "runtimes/java"
  )

  local files=(
    "README.md"
    "install.sh"
    ".gitignore"
    "scripts/pull-images.sh"
    "scripts/new-project.sh"
    "scripts/stack.sh"
    "scripts/update-images.sh"
    "stacks/web-api/compose.yml"
    "stacks/microservices/compose.yml"
    "stacks/microservices/prometheus.yml"
    "stacks/devops/compose.yml"
    "stacks/cloud-local/compose.yml"
    "stacks/data-ml/compose.yml"
    "runtimes/node/Dockerfile"
    "runtimes/node/compose-service.yml"
    "runtimes/python/Dockerfile"
    "runtimes/python/compose-service.yml"
    "runtimes/rust/Dockerfile"
    "runtimes/rust/compose-service.yml"
    "runtimes/go/Dockerfile"
    "runtimes/go/compose-service.yml"
    "runtimes/java/Dockerfile"
    "runtimes/java/compose-service.yml"
  )

  for dir in "${dirs[@]}"; do
    mkdir -p "$INSTALL_DIR/$dir"
  done

  for file in "${files[@]}"; do
    local url="${RAW_URL}/${file}"
    local dest="${INSTALL_DIR}/${file}"
    log "Downloading $file..."
    curl -fsSL "$url" -o "$dest" || warn "Could not download $file"
  done

  success "Downloaded all files to $INSTALL_DIR"
}

# ── Make scripts executable ───────────────────────────────────────────────────
step "Setting permissions"

chmod +x "$INSTALL_DIR/scripts/pull-images.sh"
chmod +x "$INSTALL_DIR/scripts/new-project.sh"
chmod +x "$INSTALL_DIR/scripts/stack.sh"
chmod +x "$INSTALL_DIR/scripts/update-images.sh"
chmod +x "$INSTALL_DIR/install.sh"
success "Scripts are now executable"

# ── Add to PATH ───────────────────────────────────────────────────────────────
if $DO_PATH; then
  step "Adding scripts to PATH"

  # Detect shell rc file
  SHELL_RC=""
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$(basename "${SHELL:-}")" == "zsh" ]]; then
    SHELL_RC="${HOME}/.zshrc"
  elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$(basename "${SHELL:-}")" == "bash" ]]; then
    SHELL_RC="${HOME}/.bashrc"
  else
    SHELL_RC="${HOME}/.profile"
  fi

  EXPORT_LINE="export PATH=\"\$PATH:${INSTALL_DIR}/scripts\""
  ALIAS_LINE="alias pds='${INSTALL_DIR}/scripts/stack.sh'"

  if grep -qF "$INSTALL_DIR/scripts" "$SHELL_RC" 2>/dev/null; then
    warn "PATH entry already present in $SHELL_RC — skipping"
  else
    {
      echo ""
      echo "# Podman Dev Stacks"
      echo "$EXPORT_LINE"
      echo "$ALIAS_LINE"
    } >> "$SHELL_RC"
    success "Added to $SHELL_RC"
    log "Run ${BOLD}source $SHELL_RC${RESET} or open a new terminal to activate"
  fi
fi

# ── Pull images ───────────────────────────────────────────────────────────────
if $DO_PULL; then
  step "Pulling images"
  log "This may take a while depending on your connection..."
  echo ""
  bash "$INSTALL_DIR/scripts/pull-images.sh" all
else
  log "Skipping image pull (--no-pull). Run later with:"
  echo "    pull-images.sh [category]"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║   ✓  Installation complete!                      ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${BOLD}Installed to:${RESET} $INSTALL_DIR"
echo ""
echo -e "${BOLD}Quick commands (after reloading shell):${RESET}"
echo ""
echo -e "  ${CYAN}# Start a stack${RESET}"
echo -e "  stack.sh up web-api"
echo ""
echo -e "  ${CYAN}# Bootstrap a new project${RESET}"
echo -e "  new-project.sh my-api web-api --node"
echo ""
echo -e "  ${CYAN}# Or use the short alias${RESET}"
echo -e "  pds up web-api"
echo ""
echo -e "  ${CYAN}# Pull more images later${RESET}"
echo -e "  pull-images.sh databases"
echo ""
echo -e "  ${CYAN}# Update all images to latest versions${RESET}"
echo -e "  update-images.sh"
echo ""
echo -e "  ${CYAN}# Check what's outdated without pulling${RESET}"
echo -e "  update-images.sh --check"
echo ""
echo -e "  ${CYAN}# Full docs${RESET}"
echo -e "  cat ${INSTALL_DIR}/README.md"
echo ""
