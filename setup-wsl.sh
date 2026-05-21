#!/bin/bash
# =============================================================================
# WSL Setup Script
# Ubuntu/Debian | zsh + oh-my-zsh + powerlevel10k + Docker + Dev tools
# =============================================================================

set -e

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

if [[ "$DISTRO_ID" != "ubuntu" && "$DISTRO_ID" != "debian" ]]; then
  error_exit "Distro '$DISTRO_ID' not supported. This script requires Ubuntu or Debian."
fi

if [ "$DISTRO_ID" = "ubuntu" ]; then
  MAJOR=$(echo "$DISTRO_VERSION" | cut -d. -f1)
  if [ "$MAJOR" -lt 22 ]; then
    error_exit "Ubuntu $DISTRO_VERSION not supported. Minimum version: 22.04."
  fi
elif [ "$DISTRO_ID" = "debian" ]; then
  if [ "$DISTRO_VERSION" -lt 11 ]; then
    error_exit "Debian $DISTRO_VERSION not supported. Minimum version: 11 (Bullseye)."
  fi
fi

echo ""
echo "✔ Compatibility check passed: $DISTRO_ID $DISTRO_VERSION ($ARCH)"
echo ""

# =============================================================================
# CORES E FUNÇÕES
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()    { echo -e "${GREEN}[✔]${NC} $1"; }
info()   { echo -e "${CYAN}[→]${NC} $1"; }
skip()   { echo -e "${GREEN}[✔]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
header() { echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}"; \
           echo -e "${BOLD}${CYAN}║  $1$(printf '%*s' $((36 - ${#1})) '')║${NC}"; \
           echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}\n"; }

# Request sudo once and keep cache alive throughout the script

# Request sudo only if cache is not active
if ! sudo -n true 2>/dev/null; then
  info "sudo password required."
  sudo -v
fi
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &

# =============================================================================
# 1. ATUALIZAÇÃO DO SISTEMA
# =============================================================================
header "1/5 · System update"

sudo apt-get update -qq
sudo apt-get install -y -qq lsb-release
sudo apt-get upgrade -y -qq
log "System updated"

# =============================================================================
# 2. PACOTES BASE
# =============================================================================
header "2/5 · Base packages"

PACKAGES=(
  apt-transport-https ca-certificates curl wget gnupg
  software-properties-common
  zsh git make tree jq ripgrep
  python3 python3-pip pipx
  gcc unzip fuse
  htop net-tools iproute2 dnsutils
)

sudo apt-get install -y "${PACKAGES[@]}" -qq

# Install venv for the current Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
sudo apt-get install -y "python${PYTHON_VERSION}-venv" -qq 2>/dev/null \
  || warn "python${PYTHON_VERSION}-venv not found — use uv for virtual environments"

log "Base packages installed (Python ${PYTHON_VERSION})"

# =============================================================================
# 3. DOCKER
# =============================================================================
header "3/5 · Docker"

if ! command -v docker &>/dev/null; then
  info "Adding Docker repository..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
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
# 4. NODE.JS LTS
# =============================================================================
# 5. FERRAMENTAS DE DESENVOLVIMENTO
# =============================================================================
header "4/5 · Tools"

# Export PATH early so installed tools are found in subsequent checks
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/go/bin:$PATH"

# — Go (via site oficial)
if ! /usr/local/go/bin/go version &>/dev/null; then
  info "Installing Go..."
  GO_VERSION=$(curl -fsSL --max-time 10 "https://go.dev/dl/?mode=json" \
    | jq -r '.[0].version' 2>/dev/null)
  [ -z "$GO_VERSION" ] || [ "$GO_VERSION" = "null" ] && GO_VERSION="go1.24.3"
  sudo rm -rf /usr/local/go
  curl -fsSL "https://dl.google.com/go/${GO_VERSION}.linux-amd64.tar.gz" \
    | sudo tar -xz -C /usr/local
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
if ! command -v pre-commit &>/dev/null; then
  info "Installing pre-commit..."
  pipx install pre-commit
  hash -r
  log "pre-commit $(pre-commit --version) installed"
else
  skip "pre-commit already installed ($(pre-commit --version)), skipping..."
fi

# — xh
if ! command -v xh &>/dev/null; then
  info "Installing xh..."
  XH_VERSION="v0.23.0"
  curl -fsSL "https://github.com/ducaale/xh/releases/download/${XH_VERSION}/xh-${XH_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz --strip-components=1 -C /tmp "xh-${XH_VERSION}-x86_64-unknown-linux-musl/xh"
  sudo install -o root -g root -m 0755 /tmp/xh /usr/local/bin/xh
  rm -f /tmp/xh
  log "xh $(xh --version) installed"
else
  skip "xh already installed ($(xh --version)), skipping..."
fi

# — sops
if ! command -v sops &>/dev/null; then
  info "Installing sops..."
  SOPS_VERSION="v3.9.4"
  curl -fsSLo /tmp/sops \
    "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64"
  sudo install -o root -g root -m 0755 /tmp/sops /usr/local/bin/sops
  rm /tmp/sops
  log "sops ${SOPS_VERSION} installed"
else
  skip "sops already installed ($(sops --version)), skipping..."
fi

# — kubectl
if ! command -v kubectl &>/dev/null; then
  info "Installing kubectl..."
  KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  curl -fsSLo /tmp/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm /tmp/kubectl
  log "kubectl ${KUBECTL_VERSION} installed"
else
  skip "kubectl already installed, skipping..."
fi

# — kind
if ! command -v kind &>/dev/null; then
  info "Installing kind..."
  KIND_VERSION="v0.27.0"
  curl -fsSLo /tmp/kind \
    "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
  sudo install -o root -g root -m 0755 /tmp/kind /usr/local/bin/kind
  rm /tmp/kind
  log "kind ${KIND_VERSION} installed"
else
  skip "kind already installed ($(kind --version)), skipping..."
fi

# — Helm
if ! command -v helm &>/dev/null; then
  info "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  log "Helm $(helm version --short) installed"
else
  skip "Helm already installed ($(helm version --short)), skipping..."
fi

# — k9s
if ! command -v k9s &>/dev/null; then
  info "Installing k9s..."
  K9S_VERSION="v0.32.7"
  curl -fsSL --max-time 60 "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" \
    | sudo tar -xz -C /usr/local/bin k9s
  log "k9s ${K9S_VERSION} installed"
else
  skip "k9s already installed, skipping..."
fi

# — Terraform
if ! command -v terraform &>/dev/null; then
  info "Installing Terraform..."
  wget -O - https://apt.releases.hashicorp.com/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y terraform -qq
  log "Terraform $(terraform version -json | jq -r '.terraform_version') installed"
else
  skip "Terraform already installed, skipping..."
fi

# — AWS CLI v2
if ! command -v aws &>/dev/null; then
  info "Installing AWS CLI v2..."
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp/aws-install
  sudo /tmp/aws-install/aws/install
  rm -rf /tmp/awscliv2.zip /tmp/aws-install
  log "AWS CLI $(aws --version 2>&1 | cut -d' ' -f1) installed"
else
  skip "AWS CLI already installed, skipping..."
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
  curl -fsSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
  log "tflint installed"
else
  skip "tflint already installed, skipping..."
fi

# — trivy (segurança IaC + containers)
if ! command -v trivy &>/dev/null; then
  info "Installing trivy..."
  curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y trivy -qq
  log "trivy installed"
else
  skip "trivy already installed, skipping..."
fi

# — hadolint (Dockerfile)
if ! command -v hadolint &>/dev/null; then
  info "Installing hadolint..."
  HADOLINT_VERSION="v2.12.0"
  curl -fsSLo /tmp/hadolint \
    "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64"
  sudo install -o root -g root -m 0755 /tmp/hadolint /usr/local/bin/hadolint
  rm /tmp/hadolint
  log "hadolint $(hadolint --version) installed"
else
  skip "hadolint already installed, skipping..."
fi

# — kubeconform (manifests Kubernetes)
if ! command -v kubeconform &>/dev/null; then
  info "Installing kubeconform..."
  KUBECONFORM_VERSION="v0.6.7"
  curl -fsSL "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
    | sudo tar -xz -C /usr/local/bin kubeconform
  log "kubeconform installed"
else
  skip "kubeconform already installed, skipping..."
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
  terraform
  aws
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# PATH
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/go/bin:$PATH"
export PIPX_HOME="$HOME/.local/pipx"

# Aliases — geral
alias ll='ls -lah'

# Aliases — git
alias gs='git status'
alias gc='git commit'
alias gp='git push'

# Aliases — docker
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'

# Aliases — kubectl
alias kc='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'

# Aliases — terraform
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'

# uv autocompletion
eval "$(uv generate-shell-completion zsh)"

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
log "git configured"

# — Backup SSH
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')

# — .wslconfig com mirrored networking (resolve compatibilidade com VPN/Boundary)
WSLCONFIG="/mnt/c/Users/${WIN_USER}/.wslconfig"
WSLCONFIG_UPDATED=false
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
SSH_BACKUP_DIR="/mnt/c/Users/${WIN_USER}/.ssh-backup-wsl"

if [ -d "$HOME/.ssh" ] && [ -n "$(ls -A "$HOME/.ssh" 2>/dev/null)" ]; then
  info "Backing up SSH keys..."
  mkdir -p "$SSH_BACKUP_DIR"
  cp -r "$HOME/.ssh/." "$SSH_BACKUP_DIR/"
  chmod 700 "$SSH_BACKUP_DIR"
  chmod 600 "$SSH_BACKUP_DIR"/* 2>/dev/null || true
  log "SSH backup saved to: C:\\Users\\${WIN_USER}\\.ssh-backup-wsl"
else
  warn "No SSH keys found in ~/.ssh — backup skipped"
fi

# — VS Code
if command -v code &>/dev/null; then
  info "Installing Remote WSL extension..."
  code --install-extension ms-vscode-remote.remote-wsl 2>/dev/null
  log "Remote WSL installed"

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  VSIX_PATH="$SCRIPT_DIR/dracula-pro.vsix"
  if [ -f "$VSIX_PATH" ]; then
    info "Installing Dracula Pro..."
    code --install-extension "$VSIX_PATH" 2>/dev/null
    log "Dracula Pro installed — activate via: Ctrl+Shift+P → Color Theme → Dracula Pro"
  else
    info "Installing Dracula (free)..."
    code --install-extension dracula-theme.theme-dracula 2>/dev/null
    log "Dracula installed — activate via: Ctrl+Shift+P → Color Theme → Dracula"
  fi

  # — Configure VS Code integrated terminal font to MesloLGS NF
  VSCODE_SETTINGS="/mnt/c/Users/${WIN_USER}/AppData/Roaming/Code/User/settings.json"
  if [ -f "$VSCODE_SETTINGS" ]; then
    info "Configuring VS Code integrated terminal font..."
    cp "$VSCODE_SETTINGS" "${VSCODE_SETTINGS}.bak"
    python3 - "$VSCODE_SETTINGS" << 'PYEOF'
import sys, json

settings_path = sys.argv[1]

try:
    with open(settings_path, "r", encoding="utf-8") as f:
        settings = json.load(f)
except json.JSONDecodeError:
    settings = {}

settings["terminal.integrated.fontFamily"] = "MesloLGS NF"
settings["terminal.integrated.fontSize"] = 14

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=4, ensure_ascii=False)
PYEOF
    log "MesloLGS NF font configured in VS Code terminal"
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
import sys, json

settings_path = sys.argv[1]
new_scheme = json.loads(sys.argv[2])

with open(settings_path, "r", encoding="utf-8") as f:
    settings = json.load(f)

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
BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"
FONTS=("MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf")
FONT_TMP="$(mktemp -d)"

for font in "${FONTS[@]}"; do
  encoded="${font// /%20}"
  curl -fsSL "${BASE_URL}/${encoded}" -o "$FONT_TMP/${font}"
done

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
