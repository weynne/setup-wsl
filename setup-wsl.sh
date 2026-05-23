#!/bin/bash
# =============================================================================
# WSL Setup Script
# Ubuntu 22.04+ | zsh + oh-my-zsh + powerlevel10k + Docker + Dev tools
# =============================================================================

set -e

# Fallback para $USER em ambientes WSL minimal onde a variável não vem exportada
USER="${USER:-$(id -un)}"

# =============================================================================
# VERIFICAÇÃO DE COMPATIBILIDADE
# =============================================================================

ARCH=$(uname -m)
DISTRO_ID=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
DISTRO_VERSION=$(grep "^VERSION_ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')

error_exit() {
  echo ""
  echo "✖ COMPATIBILITY ERROR: $1"
  echo ""
  exit 1
}

if [ "$ARCH" != "x86_64" ]; then
  error_exit "Architecture '$ARCH' not supported. This script requires x86_64."
fi

if [ "$DISTRO_ID" != "ubuntu" ]; then
  error_exit "Distro '$DISTRO_ID' not supported. This script requires Ubuntu 22.04+."
fi

MAJOR=$(echo "$DISTRO_VERSION" | cut -d. -f1)
if [ "$MAJOR" -lt 22 ]; then
  error_exit "Ubuntu $DISTRO_VERSION not supported. Minimum version: 22.04."
fi

echo ""
echo "✔ Compatibility check passed: $DISTRO_ID $DISTRO_VERSION ($ARCH)"
echo ""

# =============================================================================
# CORES E FUNÇÕES
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()    { echo -e "${GREEN}[✔]${NC} $1"; }
info()   { echo -e "${CYAN}[→]${NC} $1"; }
skip()   { echo -e "${CYAN}[~]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
header() { echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}"; \
           echo -e "${BOLD}${CYAN}║  $1$(printf '%*s' $((36 - ${#1})) '')║${NC}"; \
           echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}\n"; }

# Resolve a tag do último release no GitHub. Em caso de falha (rate-limit/rede),
# devolve string vazia e quem chama decide se aborta ou apenas avisa (warn).
github_latest_tag() {
  local tag
  tag=$(curl -fsSL --max-time 15 "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | jq -r '.tag_name' 2>/dev/null)
  if [ -z "$tag" ] || [ "$tag" = "null" ]; then
    return 1
  fi
  echo "$tag"
}

# =============================================================================
# CODENAME (real + seguro para repositórios de terceiros)
# =============================================================================
# VERSION_CODENAME costuma vir preenchido no Ubuntu, mas imagens WSL minimal às
# vezes não trazem o campo — daí o fallback para lsb_release.
VERSION_CODENAME=$(grep -E "^(VERSION_CODENAME|UBUNTU_CODENAME)=" /etc/os-release 2>/dev/null \
  | head -n1 | cut -d= -f2 | tr -d '"')
if [ -z "$VERSION_CODENAME" ] && command -v lsb_release &>/dev/null; then
  VERSION_CODENAME=$(lsb_release -cs 2>/dev/null)
fi

# Codenames de LTS que SABEMOS ter repositório publicado pelos vendors
# (Docker, HashiCorp, Trivy etc). Ubuntu não-LTS ou mais novos que o último
# repo publicado (ex: 26.04) caem no fallback abaixo.
KNOWN_REPO_CODENAMES=("jammy" "noble")
# Último LTS conhecido — usado como fallback quando o codename atual ainda não
# tem repo de terceiros publicado.
FALLBACK_CODENAME="noble"

resolve_repo_codename() {
  local cn
  for cn in "${KNOWN_REPO_CODENAMES[@]}"; do
    if [ "$VERSION_CODENAME" = "$cn" ]; then
      echo "$VERSION_CODENAME"
      return
    fi
  done
  echo "$FALLBACK_CODENAME"
}

REPO_CODENAME=$(resolve_repo_codename)
if [ "$REPO_CODENAME" != "$VERSION_CODENAME" ]; then
  warn "Codename '$VERSION_CODENAME' has no published third-party repo yet — using '$REPO_CODENAME' for Docker/HashiCorp/Trivy."
fi

# =============================================================================
# SUDO
# =============================================================================
# Request sudo only if cache is not active
if ! sudo -n true 2>/dev/null; then
  info "sudo password required."
  sudo -v
fi
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

repair_docker_apt_source() {
  local docker_source="/etc/apt/sources.list.d/docker.list"

  if [ -f "$docker_source" ] && grep -q "download.docker.com/linux/ubuntu" "$docker_source"; then
    info "Repairing Docker apt source..."
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu %s stable\n' \
      "$(dpkg --print-architecture)" \
      "$REPO_CODENAME" \
      | sudo tee "$docker_source" > /dev/null
  fi
}

# =============================================================================
# 1. ATUALIZAÇÃO DO SISTEMA
# =============================================================================
header "1/5 · System update"

sudo apt-get update -qq
# Garante lsb-release ANTES de qualquer uso de codename
sudo apt-get install -y -qq lsb-release

# Reconfirma o codename agora que lsb-release está disponível
if [ -z "$VERSION_CODENAME" ]; then
  VERSION_CODENAME=$(lsb_release -cs 2>/dev/null)
  REPO_CODENAME=$(resolve_repo_codename)
fi
if [ -z "$VERSION_CODENAME" ]; then
  error_exit "Could not determine Ubuntu codename (VERSION_CODENAME empty and lsb_release failed)."
fi

repair_docker_apt_source

sudo apt-get upgrade -y -qq
log "System updated (codename: $VERSION_CODENAME, repo codename: $REPO_CODENAME)"

# =============================================================================
# 2. PACOTES BASE
# =============================================================================
header "2/5 · Base packages"

PACKAGES=(
  apt-transport-https ca-certificates curl wget gnupg
  software-properties-common
  zsh git make tree jq ripgrep fzf bat fd-find direnv shfmt
  python3 python3-pip pipx
  gcc unzip fuse
  age
  htop net-tools iproute2 dnsutils
  tmux
)

sudo apt-get install -y "${PACKAGES[@]}" -qq

# Install venv for the current Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
sudo apt-get install -y "python${PYTHON_VERSION}-venv" -qq 2>/dev/null \
  || warn "python${PYTHON_VERSION}-venv not found — use uv for virtual environments"

# Garante que ~/.local/bin (pipx) entre no PATH dos próximos checks
pipx ensurepath >/dev/null 2>&1 || true

log "Base packages installed (Python ${PYTHON_VERSION})"

# =============================================================================
# 3. DOCKER
# =============================================================================
header "3/5 · Docker"

if ! command -v docker &>/dev/null; then
  info "Adding Docker repository..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" \
    | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu %s stable\n' \
    "$(dpkg --print-architecture)" \
    "$REPO_CODENAME" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    containerd.io docker-ce docker-ce-cli \
    docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
  log "Docker installed"
else
  skip "Docker already installed, skipping..."
fi

# =============================================================================
# 4. FERRAMENTAS DE DESENVOLVIMENTO
# =============================================================================
header "4/5 · Tools"

# Export PATH early so installed tools are found in subsequent checks
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/go/bin:$PATH"

# — Go (via site oficial)
if ! /usr/local/go/bin/go version &>/dev/null; then
  info "Installing Go..."
  GO_VERSION=$(curl -fsSL --max-time 10 "https://go.dev/dl/?mode=json" \
    | jq -r '.[0].version' 2>/dev/null)
  if [ -z "$GO_VERSION" ] || [ "$GO_VERSION" = "null" ]; then
    error_exit "Could not resolve latest Go version."
  fi
  sudo rm -rf /usr/local/go
  curl -fsSL "https://dl.google.com/go/${GO_VERSION}.linux-amd64.tar.gz" \
    | sudo tar -xz -C /usr/local
  # shellcheck disable=SC2016
  grep -qxF 'export PATH="$PATH:/usr/local/go/bin"' "$HOME/.profile" \
    || echo 'export PATH="$PATH:/usr/local/go/bin"' >> "$HOME/.profile"
  log "Go $(/usr/local/go/bin/go version) installed"
else
  skip "Go already installed ($(/usr/local/go/bin/go version)), skipping..."
fi

# — uv
if ! "$HOME/.local/bin/uv" --version &>/dev/null; then
  info "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  log "uv $("$HOME/.local/bin/uv" --version) installed"
else
  skip "uv already installed ($("$HOME/.local/bin/uv" --version)), skipping..."
fi

# — pre-commit
if ! command -v pre-commit &>/dev/null; then
  info "Installing pre-commit..."
  pipx install pre-commit
  hash -r
  log "pre-commit $(pre-commit --version) installed"
else
  skip "pre-commit already installed ($(pre-commit --version)), skipping..."
fi

# — Node.js LTS
if ! command -v node &>/dev/null; then
  info "Installing Node.js LTS..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs -qq
  log "Node.js $(node --version) installed"
else
  skip "Node.js already installed ($(node --version)), skipping..."
fi

# — npm (upgrade to latest)
info "Upgrading npm to latest..."
sudo npm install -g npm@latest
log "npm $(npm --version) installed"

# — markdownlint-cli2
if ! command -v markdownlint-cli2 &>/dev/null; then
  info "Installing markdownlint-cli2..."
  sudo npm install -g markdownlint-cli2
  log "markdownlint-cli2 installed"
else
  skip "markdownlint-cli2 already installed, skipping..."
fi

# — xh
if ! command -v xh &>/dev/null; then
  info "Installing xh..."
  if XH_VERSION=$(github_latest_tag "ducaale/xh"); then
    curl -fsSL "https://github.com/ducaale/xh/releases/download/${XH_VERSION}/xh-${XH_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      | tar -xz --strip-components=1 -C /tmp "xh-${XH_VERSION}-x86_64-unknown-linux-musl/xh" \
      && sudo install -o root -g root -m 0755 /tmp/xh /usr/local/bin/xh \
      && rm -f /tmp/xh \
      && log "xh $(xh --version) installed" \
      || warn "xh install failed — skipping."
  else
    warn "Could not resolve xh release (GitHub rate-limit?) — skipping."
  fi
else
  skip "xh already installed ($(xh --version)), skipping..."
fi

# — sops
if ! command -v sops &>/dev/null; then
  info "Installing sops..."
  if SOPS_VERSION=$(github_latest_tag "getsops/sops"); then
    curl -fsSLo /tmp/sops \
      "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64" \
      && sudo install -o root -g root -m 0755 /tmp/sops /usr/local/bin/sops \
      && rm -f /tmp/sops \
      && log "sops ${SOPS_VERSION} installed" \
      || warn "sops install failed — skipping."
  else
    warn "Could not resolve sops release — skipping."
  fi
else
  skip "sops already installed ($(sops --version)), skipping..."
fi

# — GitHub CLI
if ! command -v gh &>/dev/null; then
  info "Installing GitHub CLI..."
  if GH_TAG=$(github_latest_tag "cli/cli"); then
    GH_VERSION="${GH_TAG#v}"
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
      | tar -xz -C /tmp \
      && sudo install -o root -g root -m 0755 "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh \
      && rm -rf "/tmp/gh_${GH_VERSION}_linux_amd64" \
      && log "GitHub CLI $(gh --version | head -n1) installed" \
      || warn "GitHub CLI install failed — skipping."
  else
    warn "Could not resolve GitHub CLI release — skipping."
  fi
else
  skip "GitHub CLI already installed ($(gh --version | head -n1)), skipping..."
fi

# — eza
if ! command -v eza &>/dev/null; then
  info "Installing eza..."
  if EZA_VERSION=$(github_latest_tag "eza-community/eza"); then
    curl -fsSL "https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" \
      | tar -xz --strip-components=1 -C /tmp ./eza \
      && sudo install -o root -g root -m 0755 /tmp/eza /usr/local/bin/eza \
      && rm -f /tmp/eza \
      && log "eza $(eza --version | head -n1) installed" \
      || warn "eza install failed — skipping."
  else
    warn "Could not resolve eza release — skipping."
  fi
else
  skip "eza already installed ($(eza --version | head -n1)), skipping..."
fi

# — yq
if ! command -v yq &>/dev/null; then
  info "Installing yq..."
  if YQ_VERSION=$(github_latest_tag "mikefarah/yq"); then
    curl -fsSLo /tmp/yq \
      "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
      && sudo install -o root -g root -m 0755 /tmp/yq /usr/local/bin/yq \
      && rm -f /tmp/yq \
      && log "yq $(yq --version) installed" \
      || warn "yq install failed — skipping."
  else
    warn "Could not resolve yq release — skipping."
  fi
else
  skip "yq already installed ($(yq --version)), skipping..."
fi

# — Neovim
if ! command -v nvim &>/dev/null; then
  info "Installing Neovim..."
  if NVIM_VERSION=$(github_latest_tag "neovim/neovim"); then
    curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
      | sudo tar -xz -C /opt \
      && sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim \
      && log "Neovim $(nvim --version | head -n1) installed" \
      || warn "Neovim install failed — skipping."
  else
    warn "Could not resolve Neovim release — skipping."
  fi
else
  skip "Neovim already installed ($(nvim --version | head -n1)), skipping..."
fi

# — lazygit
if ! command -v lazygit &>/dev/null; then
  info "Installing lazygit..."
  if LAZYGIT_VERSION=$(github_latest_tag "jesseduffield/lazygit"); then
    LAZYGIT_VERSION_NUMBER="${LAZYGIT_VERSION#v}"
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION_NUMBER}_Linux_x86_64.tar.gz" \
      | tar -xz -C /tmp lazygit \
      && sudo install -o root -g root -m 0755 /tmp/lazygit /usr/local/bin/lazygit \
      && rm -f /tmp/lazygit \
      && log "lazygit $(lazygit --version) installed" \
      || warn "lazygit install failed — skipping."
  else
    warn "Could not resolve lazygit release — skipping."
  fi
else
  skip "lazygit already installed ($(lazygit --version)), skipping..."
fi

# — lazydocker
if ! command -v lazydocker &>/dev/null; then
  info "Installing lazydocker..."
  if LAZYDOCKER_VERSION=$(github_latest_tag "jesseduffield/lazydocker"); then
    LAZYDOCKER_VERSION_NUMBER="${LAZYDOCKER_VERSION#v}"
    curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION_NUMBER}_Linux_x86_64.tar.gz" \
      | tar -xz -C /tmp lazydocker \
      && sudo install -o root -g root -m 0755 /tmp/lazydocker /usr/local/bin/lazydocker \
      && rm -f /tmp/lazydocker \
      && log "lazydocker $(lazydocker --version) installed" \
      || warn "lazydocker install failed — skipping."
  else
    warn "Could not resolve lazydocker release — skipping."
  fi
else
  skip "lazydocker already installed ($(lazydocker --version)), skipping..."
fi

# — dive
if ! command -v dive &>/dev/null; then
  info "Installing dive..."
  if DIVE_VERSION=$(github_latest_tag "wagoodman/dive"); then
    DIVE_TMP=$(mktemp /tmp/dive_XXXXXX.tar.gz)
    if curl -fsSL --retry 3 \
      "https://github.com/wagoodman/dive/releases/download/${DIVE_VERSION}/dive_${DIVE_VERSION#v}_linux_amd64.tar.gz" \
      -o "$DIVE_TMP"; then
      tar -xz -C /tmp -f "$DIVE_TMP" dive
      sudo install -o root -g root -m 0755 /tmp/dive /usr/local/bin/dive
      rm -f /tmp/dive
      log "dive $(dive --version) installed"
    else
      warn "dive download failed (HTTP error) — skipping. Install manually: https://github.com/wagoodman/dive/releases"
    fi
    rm -f "$DIVE_TMP"
  else
    warn "Could not resolve dive release — skipping."
  fi
else
  skip "dive already installed ($(dive --version)), skipping..."
fi

# — kubectl
if ! command -v kubectl &>/dev/null; then
  info "Installing kubectl..."
  KUBECTL_VERSION=$(curl -fsSL --max-time 15 https://dl.k8s.io/release/stable.txt 2>/dev/null)
  if [ -n "$KUBECTL_VERSION" ]; then
    curl -fsSLo /tmp/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
      && sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl \
      && rm -f /tmp/kubectl \
      && log "kubectl ${KUBECTL_VERSION} installed" \
      || warn "kubectl install failed — skipping."
  else
    warn "Could not resolve kubectl version — skipping."
  fi
else
  skip "kubectl already installed, skipping..."
fi

# — kind
if ! command -v kind &>/dev/null; then
  info "Installing kind..."
  if KIND_VERSION=$(github_latest_tag "kubernetes-sigs/kind"); then
    curl -fsSLo /tmp/kind \
      "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" \
      && sudo install -o root -g root -m 0755 /tmp/kind /usr/local/bin/kind \
      && rm -f /tmp/kind \
      && log "kind ${KIND_VERSION} installed" \
      || warn "kind install failed — skipping."
  else
    warn "Could not resolve kind release — skipping."
  fi
else
  skip "kind already installed ($(kind --version)), skipping..."
fi

# — Helm
if ! command -v helm &>/dev/null; then
  info "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash \
    && log "Helm $(helm version --short) installed" \
    || warn "Helm install failed — skipping."
else
  skip "Helm already installed ($(helm version --short)), skipping..."
fi

# — k9s
if ! command -v k9s &>/dev/null; then
  info "Installing k9s..."
  if K9S_VERSION=$(github_latest_tag "derailed/k9s"); then
    curl -fsSL --max-time 60 "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" \
      | sudo tar -xz -C /usr/local/bin k9s \
      && log "k9s ${K9S_VERSION} installed" \
      || warn "k9s install failed — skipping."
  else
    warn "Could not resolve k9s release — skipping."
  fi
else
  skip "k9s already installed, skipping..."
fi

# — kubectx + kubens
if ! command -v kubectx &>/dev/null; then
  info "Installing kubectx + kubens..."
  if KUBECTX_VERSION=$(github_latest_tag "ahmetb/kubectx"); then
    curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubectx_${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
      | tar -xz -C /tmp kubectx \
      && sudo install -o root -g root -m 0755 /tmp/kubectx /usr/local/bin/kubectx \
      && rm -f /tmp/kubectx
    curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubens_${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
      | tar -xz -C /tmp kubens \
      && sudo install -o root -g root -m 0755 /tmp/kubens /usr/local/bin/kubens \
      && rm -f /tmp/kubens \
      && log "kubectx + kubens ${KUBECTX_VERSION} installed" \
      || warn "kubectx/kubens install failed — skipping."
  else
    warn "Could not resolve kubectx release — skipping."
  fi
else
  skip "kubectx already installed ($(kubectx --version 2>/dev/null || echo n/a)), skipping..."
fi

# — stern
if ! command -v stern &>/dev/null; then
  info "Installing stern..."
  if STERN_VERSION=$(github_latest_tag "stern/stern"); then
    curl -fsSL "https://github.com/stern/stern/releases/download/${STERN_VERSION}/stern_${STERN_VERSION#v}_linux_amd64.tar.gz" \
      | tar -xz -C /tmp stern \
      && sudo install -o root -g root -m 0755 /tmp/stern /usr/local/bin/stern \
      && rm -f /tmp/stern \
      && log "stern $(stern --version) installed" \
      || warn "stern install failed — skipping."
  else
    warn "Could not resolve stern release — skipping."
  fi
else
  skip "stern already installed ($(stern --version)), skipping..."
fi

# — Terraform
if ! command -v terraform &>/dev/null; then
  info "Installing Terraform..."
  wget -O - https://apt.releases.hashicorp.com/gpg \
    | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com ${REPO_CODENAME} main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y terraform -qq \
    && log "Terraform $(terraform version -json | jq -r '.terraform_version') installed" \
    || warn "Terraform install failed — skipping."
else
  skip "Terraform already installed, skipping..."
fi

# — AWS CLI
if ! command -v aws &>/dev/null; then
  info "Installing AWS CLI..."
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && sudo /tmp/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws \
    && log "AWS CLI $(aws --version 2>&1) installed" \
    || warn "AWS CLI install failed — skipping."
else
  skip "AWS CLI already installed ($(aws --version 2>&1)), skipping..."
fi

# — git-delta
if ! command -v delta &>/dev/null; then
  info "Installing git-delta..."
  if DELTA_TAG=$(github_latest_tag "dandavison/delta"); then
    DELTA_VERSION="${DELTA_TAG#v}"
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_TAG}/delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
      | tar -xz -C /tmp \
      && sudo install -o root -g root -m 0755 "/tmp/delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu/delta" /usr/local/bin/delta \
      && rm -rf "/tmp/delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu" \
      && log "git-delta $(delta --version) installed" \
      || warn "git-delta install failed — skipping."
  else
    warn "Could not resolve git-delta release — skipping."
  fi
else
  skip "git-delta already installed ($(delta --version)), skipping..."
fi

# — zoxide
if ! command -v zoxide &>/dev/null; then
  info "Installing zoxide..."
  if ZOXIDE_VERSION=$(github_latest_tag "ajeetdsouza/zoxide"); then
    curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION#v}-x86_64-unknown-linux-musl.tar.gz" \
      | tar -xz -C /tmp zoxide \
      && sudo install -o root -g root -m 0755 /tmp/zoxide /usr/local/bin/zoxide \
      && rm -f /tmp/zoxide \
      && log "zoxide $(zoxide --version) installed" \
      || warn "zoxide install failed — skipping."
  else
    warn "Could not resolve zoxide release — skipping."
  fi
else
  skip "zoxide already installed ($(zoxide --version)), skipping..."
fi

# — task (Taskfile)
if ! command -v task &>/dev/null; then
  info "Installing task (Taskfile)..."
  if TASK_VERSION=$(github_latest_tag "go-task/task"); then
    curl -fsSL "https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_amd64.tar.gz" \
      | tar -xz -C /tmp task \
      && sudo install -o root -g root -m 0755 /tmp/task /usr/local/bin/task \
      && rm -f /tmp/task \
      && log "task $(task --version) installed" \
      || warn "task install failed — skipping."
  else
    warn "Could not resolve task release — skipping."
  fi
else
  skip "task already installed ($(task --version)), skipping..."
fi

# =============================================================================
# LINTERS
# =============================================================================

# — shellcheck (bash/sh)
if ! command -v shellcheck &>/dev/null; then
  info "Installing shellcheck..."
  sudo apt-get install -y shellcheck -qq
  log "shellcheck installed"
else
  skip "shellcheck already installed, skipping..."
fi

# — yamllint (YAML)
if ! command -v yamllint &>/dev/null; then
  info "Installing yamllint..."
  pipx install yamllint
  hash -r
  log "yamllint $(yamllint --version) installed"
else
  skip "yamllint already installed, skipping..."
fi

# — ruff (Python)
if ! command -v ruff &>/dev/null; then
  info "Installing ruff..."
  pipx install ruff
  hash -r
  log "ruff $(ruff --version) installed"
else
  skip "ruff already installed, skipping..."
fi

# — tflint (Terraform)
if ! command -v tflint &>/dev/null; then
  info "Installing tflint..."
  curl -fsSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash \
    && log "tflint installed" \
    || warn "tflint install failed — skipping."
else
  skip "tflint already installed, skipping..."
fi

# — trivy (segurança IaC + containers)
if ! command -v trivy &>/dev/null; then
  info "Installing trivy..."
  curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/trivy.gpg
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y trivy -qq \
    && log "trivy installed" \
    || warn "trivy install failed — skipping."
else
  skip "trivy already installed, skipping..."
fi

# — hadolint (Dockerfile)
if ! command -v hadolint &>/dev/null; then
  info "Installing hadolint..."
  if HADOLINT_VERSION=$(github_latest_tag "hadolint/hadolint"); then
    curl -fsSLo /tmp/hadolint \
      "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
      && sudo install -o root -g root -m 0755 /tmp/hadolint /usr/local/bin/hadolint \
      && rm -f /tmp/hadolint \
      && log "hadolint $(hadolint --version) installed" \
      || warn "hadolint install failed — skipping."
  else
    warn "Could not resolve hadolint release — skipping."
  fi
else
  skip "hadolint already installed, skipping..."
fi

# — kubeconform (manifests Kubernetes)
if ! command -v kubeconform &>/dev/null; then
  info "Installing kubeconform..."
  if KUBECONFORM_VERSION=$(github_latest_tag "yannh/kubeconform"); then
    curl -fsSL "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
      | sudo tar -xz -C /usr/local/bin kubeconform \
      && log "kubeconform installed" \
      || warn "kubeconform install failed — skipping."
  else
    warn "Could not resolve kubeconform release — skipping."
  fi
else
  skip "kubeconform already installed, skipping..."
fi

# — actionlint (GitHub Actions)
if ! command -v actionlint &>/dev/null; then
  info "Installing actionlint..."
  if ACTIONLINT_VERSION=$(github_latest_tag "rhysd/actionlint"); then
    curl -fsSL "https://github.com/rhysd/actionlint/releases/download/${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION#v}_linux_amd64.tar.gz" \
      | tar -xz -C /tmp actionlint \
      && sudo install -o root -g root -m 0755 /tmp/actionlint /usr/local/bin/actionlint \
      && rm -f /tmp/actionlint \
      && log "actionlint $(actionlint --version) installed" \
      || warn "actionlint install failed — skipping."
  else
    warn "Could not resolve actionlint release — skipping."
  fi
else
  skip "actionlint already installed ($(actionlint --version)), skipping..."
fi

# — terraform-docs
if ! command -v terraform-docs &>/dev/null; then
  info "Installing terraform-docs..."
  if TERRAFORM_DOCS_VERSION=$(github_latest_tag "terraform-docs/terraform-docs"); then
    curl -fsSL "https://github.com/terraform-docs/terraform-docs/releases/download/${TERRAFORM_DOCS_VERSION}/terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz" \
      | tar -xz -C /tmp terraform-docs \
      && sudo install -o root -g root -m 0755 /tmp/terraform-docs /usr/local/bin/terraform-docs \
      && rm -f /tmp/terraform-docs \
      && log "terraform-docs $(terraform-docs --version) installed" \
      || warn "terraform-docs install failed — skipping."
  else
    warn "Could not resolve terraform-docs release — skipping."
  fi
else
  skip "terraform-docs already installed ($(terraform-docs --version)), skipping..."
fi

# — gitleaks (secrets em git)
if ! command -v gitleaks &>/dev/null; then
  info "Installing gitleaks..."
  if GITLEAKS_VERSION=$(github_latest_tag "gitleaks/gitleaks"); then
    curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION#v}_linux_x64.tar.gz" \
      | tar -xz -C /tmp gitleaks \
      && sudo install -o root -g root -m 0755 /tmp/gitleaks /usr/local/bin/gitleaks \
      && rm -f /tmp/gitleaks \
      && log "gitleaks $(gitleaks version) installed" \
      || warn "gitleaks install failed — skipping."
  else
    warn "Could not resolve gitleaks release — skipping."
  fi
else
  skip "gitleaks already installed ($(gitleaks version)), skipping..."
fi

# — checkov (segurança IaC: Terraform, K8s, Dockerfiles, GitHub Actions)
if ! command -v checkov &>/dev/null; then
  info "Installing checkov..."
  pipx install checkov
  hash -r
  log "checkov $(checkov --version) installed"
else
  skip "checkov already installed ($(checkov --version)), skipping..."
fi

# — LazyVim
if [ ! -d "$HOME/.config/nvim" ]; then
  info "Installing LazyVim starter..."
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim" -q \
    && rm -rf "$HOME/.config/nvim/.git" \
    && log "LazyVim starter installed" \
    || warn "LazyVim starter install failed — skipping."
else
  skip "Neovim config already exists at ~/.config/nvim, skipping LazyVim starter..."
fi

header "5/5 · Environment setup"

# — Default shell
if [ "$SHELL" != "$(which zsh)" ]; then
  info "Setting default shell to zsh..."
  sudo chsh -s "$(which zsh)" "$USER"
  log "Default shell set to zsh"
fi

# — Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  info "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended
  log "oh-my-zsh installed"
else
  skip "oh-my-zsh already installed, skipping..."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# — Powerlevel10k
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
  info "Installing powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k" -q
  log "Powerlevel10k installed"
else
  skip "Powerlevel10k already installed, skipping..."
fi

# — zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  info "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions" -q
  log "zsh-autosuggestions installed"
else
  skip "zsh-autosuggestions already installed, skipping..."
fi

# — zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  info "Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" -q
  log "zsh-syntax-highlighting installed"
else
  skip "zsh-syntax-highlighting already installed, skipping..."
fi

# — .zshrc
info "Generating .zshrc..."
[ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
cat > "$HOME/.zshrc" << 'ZSHRC'
# Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  docker
  docker-compose
  python
  kubectl
  helm
  terraform
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# PATH
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/go/bin:$PATH"
export PIPX_HOME="$HOME/.local/pipx"
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

# Aliases — geral
alias ll='ls -lah'
alias cat='batcat --paging=never'
alias fd='fdfind'
alias ls='eza --group-directories-first'
alias la='eza -la --group-directories-first'
alias lt='eza --tree --level=2 --group-directories-first'

# Aliases — git
alias gs='git status'
alias gc='git commit'
alias gp='git push'

# Aliases — docker
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias ld='lazydocker'

# Aliases — kubectl
alias kc='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kctx='kubectx'
alias kns='kubens'

# Aliases — terraform
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'

# uv autocompletion
command -v uv &>/dev/null && eval "$(uv generate-shell-completion zsh)"

# direnv
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# zoxide (smart cd)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# fzf keybindings/completion (Debian/Ubuntu package layout)
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh

# p10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
ZSHRC
log ".zshrc generated"

# — Configurações globais do git
info "Configuring git..."
git config --global init.defaultBranch main        # use main as default branch
git config --global pull.rebase false              # merge ao invés de rebase no pull
git config --global core.autocrlf input            # normaliza line endings (importante no WSL)
git config --global core.editor "code --wait"      # VS Code as default editor
git config --global advice.defaultBranchName false # silencia o aviso do branch name
if command -v delta &>/dev/null; then
  git config --global core.pager "delta"           # pretty diffs
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.side-by-side true
fi
log "git configured"

WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
WSLCONFIG_UPDATED=false

if [ -z "$WIN_USER" ]; then
  warn "Windows username not detected — skipping .wslconfig, VSCode and Windows Terminal setup"
else

# — .wslconfig com mirrored networking (resolve compatibilidade com VPN/Boundary)
WSLCONFIG="/mnt/c/Users/${WIN_USER}/.wslconfig"
if [ ! -f "$WSLCONFIG" ] || ! grep -q "networkingMode=mirrored" "$WSLCONFIG" 2>/dev/null; then
  info "Configuring .wslconfig with mirrored networking..."
  cat >> "$WSLCONFIG" << 'WSLCFG'

[wsl2]
networkingMode=mirrored
WSLCFG
  WSLCONFIG_UPDATED=true
  log ".wslconfig configured"
else
  skip ".wslconfig already configured, skipping..."
fi

# — VS Code
if command -v code &>/dev/null; then
  info "Installing VS Code extensions..."

  VSCODE_EXTENSIONS=(
    # Remote / WSL
    ms-vscode-remote.remote-wsl

    # Theme & UI
    dracula-theme.theme-dracula
    pkief.material-icon-theme
    usernamehw.errorlens

    # Git
    eamodio.gitlens
    mhutchie.git-graph

    # Shell
    timonwong.shellcheck

    # Python
    ms-python.python
    ms-python.vscode-pylance
    charliermarsh.ruff

    # Go
    golang.go

    # Infrastructure
    hashicorp.terraform
    ms-azuretools.vscode-docker
    ms-kubernetes-tools.vscode-kubernetes-tools
    redhat.vscode-yaml
    github.vscode-github-actions

    # Productivity
    editorconfig.editorconfig
    esbenp.prettier-vscode
  )

  for ext in "${VSCODE_EXTENSIONS[@]}"; do
    code --install-extension "$ext" --force 2>/dev/null \
      && log "  ✓ $ext" \
      || warn "  ✗ $ext (failed)"
  done

  VSCODE_COLOR_THEME="Dracula Theme"
  log "VS Code extensions installed"

  # — Configure VS Code integrated terminal font to MesloLGS NF
  VSCODE_SETTINGS="/mnt/c/Users/${WIN_USER}/AppData/Roaming/Code/User/settings.json"
  if [ -f "$VSCODE_SETTINGS" ]; then
    info "Configuring VS Code integrated terminal font..."
    cp "$VSCODE_SETTINGS" "${VSCODE_SETTINGS}.bak"
    python3 - "$VSCODE_SETTINGS" "$VSCODE_COLOR_THEME" << 'PYEOF'
import json
import re
import sys

settings_path = sys.argv[1]

def strip_jsonc(content):
    result = []
    in_string = False
    escaped = False
    i = 0

    while i < len(content):
        char = content[i]
        next_char = content[i + 1] if i + 1 < len(content) else ""

        if in_string:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            i += 1
            continue

        if char == '"':
            in_string = True
            result.append(char)
            i += 1
            continue

        if char == "/" and next_char == "/":
            i += 2
            while i < len(content) and content[i] not in "\r\n":
                i += 1
            continue

        if char == "/" and next_char == "*":
            i += 2
            while i + 1 < len(content) and not (content[i] == "*" and content[i + 1] == "/"):
                i += 1
            i += 2
            continue

        result.append(char)
        i += 1

    return re.sub(r",(\s*[}\]])", r"\1", "".join(result))

try:
    with open(settings_path, "r", encoding="utf-8") as f:
        settings = json.loads(strip_jsonc(f.read()))
except json.JSONDecodeError:
    settings = {}

settings["terminal.integrated.fontFamily"] = "MesloLGS NF"
settings["terminal.integrated.fontSize"] = 14
color_theme = sys.argv[2] if len(sys.argv) > 2 else ""
if color_theme:
    settings["workbench.colorTheme"] = color_theme

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=4, ensure_ascii=False)
PYEOF
    log "VS Code settings configured"
  else
    warn "VS Code settings.json not found — configure manually:"
    warn "  terminal.integrated.fontFamily: MesloLGS NF"
  fi
else
  warn "VS Code not found — install on Windows with 'Add to PATH' checked"
fi

# — Moonlight II theme + font for Windows Terminal
WT_SETTINGS="/mnt/c/Users/${WIN_USER}/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"

MOONLIGHT_THEME='{
    "name": "Moonlight II",
    "background": "#212337",
    "foreground": "#c8d3f5",
    "black": "#191a2a",
    "blue": "#82aaff",
    "brightBlack": "#444a73",
    "brightBlue": "#82aaff",
    "brightCyan": "#b4f9f8",
    "brightGreen": "#c3e88d",
    "brightPurple": "#fca7ea",
    "brightRed": "#ff757f",
    "brightWhite": "#c8d3f5",
    "brightYellow": "#ffc777",
    "cyan": "#86e1fc",
    "green": "#c3e88d",
    "purple": "#fca7ea",
    "red": "#ff757f",
    "white": "#828bb8",
    "yellow": "#ffc777",
    "cursorColor": "#c8d3f5",
    "selectionBackground": "#2d3f76"
}'

if [ -f "$WT_SETTINGS" ]; then
  info "Applying Moonlight II theme + MesloLGS NF font to Windows Terminal..."
  cp "$WT_SETTINGS" "${WT_SETTINGS}.bak"
  python3 - "$WT_SETTINGS" "$MOONLIGHT_THEME" << 'PYEOF'
import sys, json, re

settings_path = sys.argv[1]
new_scheme = json.loads(sys.argv[2])

def strip_jsonc(content):
    result = []
    in_string = False
    escaped = False
    i = 0
    while i < len(content):
        char = content[i]
        next_char = content[i + 1] if i + 1 < len(content) else ""
        if in_string:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            i += 1
            continue
        if char == '"':
            in_string = True
            result.append(char)
            i += 1
            continue
        if char == "/" and next_char == "/":
            i += 2
            while i < len(content) and content[i] not in "\r\n":
                i += 1
            continue
        if char == "/" and next_char == "*":
            i += 2
            while i + 1 < len(content) and not (content[i] == "*" and content[i + 1] == "/"):
                i += 1
            i += 2
            continue
        result.append(char)
        i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(result))

with open(settings_path, "r", encoding="utf-8") as f:
    settings = json.loads(strip_jsonc(f.read()))

if "schemes" not in settings:
    settings["schemes"] = []
if not any(s.get("name") == "Moonlight II" for s in settings["schemes"]):
    settings["schemes"].append(new_scheme)

for profile in settings.get("profiles", {}).get("list", []):
    name = profile.get("name", "").lower()
    source = profile.get("source", "").lower()
    if "ubuntu" in name or "ubuntu" in source:
        profile["font"] = {"face": "MesloLGS NF"}
        profile["colorScheme"] = "Moonlight II"

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=4, ensure_ascii=False)
PYEOF
  log "Windows Terminal configured"
else
  warn "Windows Terminal settings.json not found"
fi

# — Fontes MesloLGS NF via PowerShell
info "Installing MesloLGS NF fonts..."
BASE_URL="https://raw.githubusercontent.com/romkatv/powerlevel10k-media/master"
FONTS=("MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf")
FONT_TMP="$(mktemp -d /tmp/meslo_XXXXXX)"
mkdir -p "$FONT_TMP"

FONT_DOWNLOADED=0
for font in "${FONTS[@]}"; do
  encoded="${font// /%20}"
  # Quote the output path; use a safe intermediate name to avoid curl issues with spaces
  safe="${font// /_}"
  if curl -fsSL --retry 3 "${BASE_URL}/${encoded}" -o "${FONT_TMP}/${safe}"; then
    mv "${FONT_TMP}/${safe}" "${FONT_TMP}/${font}"
    FONT_DOWNLOADED=$((FONT_DOWNLOADED + 1))
  else
    warn "  Failed to download font: ${font}"
  fi
done

if [ "$FONT_DOWNLOADED" -eq 0 ]; then
  warn "No fonts downloaded — skipping PowerShell font install"
  rm -rf "$FONT_TMP"
else

WIN_FONT_TMP="$(wslpath -w "$FONT_TMP")"
powershell.exe -NoProfile -NonInteractive -Command "
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  \$userFontDir = \"\$env:LOCALAPPDATA\Microsoft\Windows\Fonts\"
  if (-not (Test-Path \$userFontDir)) { New-Item -ItemType Directory -Path \$userFontDir | Out-Null }
  Get-ChildItem -Path '${WIN_FONT_TMP}' -Filter '*.ttf' | ForEach-Object {
    \$dest = \"\$userFontDir\\\$(\$_.Name)\"
    if (-not (Test-Path \$dest)) {
      Copy-Item \$_.FullName -Destination \$dest
      \$regPath = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
      New-ItemProperty -Path \$regPath -Name \$(\$_.BaseName + ' (TrueType)') -Value \$dest -PropertyType String -Force | Out-Null
      Write-Host \"Installed: \$(\$_.Name)\"
    } else {
      Write-Host \"Already exists: \$(\$_.Name)\"
    }
  }
" 2>/dev/null
rm -rf "$FONT_TMP"
log "MesloLGS NF fonts installed"

fi  # [ "$FONT_DOWNLOADED" -eq 0 ]

fi  # [ -n "$WIN_USER" ]

# =============================================================================
# RESUMO FINAL
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   Setup completed successfully! 🎉   ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo -e "  ${CYAN}1.${NC} Start the Powerlevel10k wizard:"
echo -e "     ${YELLOW}exec zsh${NC}"
echo ""
echo -e "  ${CYAN}2.${NC} Re-login to activate the docker group:"
echo -e "     Close and reopen WSL"
echo ""
if [ "$WSLCONFIG_UPDATED" = true ]; then
echo -e "  ${CYAN}3.${NC} .wslconfig updated — apply mirrored networking:"
echo -e "     Close WSL and run in PowerShell: ${YELLOW}wsl --shutdown${NC}"
echo ""
fi
