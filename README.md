# WSL DevOps Setup

Setup automatizado para WSL (Ubuntu/Debian) com ferramentas de desenvolvimento e DevOps.

---

## Como usar

### Passo 1 — Instale o WSL no Windows

Abra o **PowerShell como administrador** e rode:

```powershell
wsl --install
```

Reinicie o computador quando solicitado. Na primeira abertura do WSL, crie seu usuário e senha.

---

### Passo 2 — Instale o VS Code no Windows

Baixe em [code.visualstudio.com](https://code.visualstudio.com) e durante a instalação marque a opção **"Add to PATH"**. Isso é necessário para o script instalar as extensões automaticamente.

---

### Passo 3 — Instale o Windows Terminal (se ainda não tiver)

Baixe na [Microsoft Store](https://aka.ms/terminal). O script configura o tema Moonlight II e a fonte automaticamente.

---

### Passo 4 — Prepare a pasta do setup

Crie uma pasta chamada `setup_wsl` em qualquer lugar no Windows (ex: `C:\Users\<seu-usuario>\setup_wsl`) e coloque os arquivos dentro:

```
📁 setup_wsl\
└── setup-wsl.sh
```

---

### Passo 5 — Rode o script

Abra o WSL, navegue até a pasta e execute:

```bash
cd /mnt/c/Users/<seu-usuario>/setup_wsl
chmod +x setup-wsl.sh
./setup-wsl.sh
```

O script vai pedir a senha sudo uma única vez no início e rodar todas as etapas automaticamente. O processo pode levar alguns minutos dependendo da sua conexão.

---

### Passo 6 — Configure o terminal

Ao final do script, rode:

```bash
exec zsh
```

O wizard do Powerlevel10k vai iniciar automaticamente para configurar o visual do terminal. Siga as instruções na tela — você pode escolher o estilo de cada elemento visualmente.

---

### Passo 7 — Reabra o WSL

Feche e reabra o WSL para ativar o grupo docker (necessário para usar o Docker sem `sudo`):

```bash
docker ps   # deve funcionar sem sudo após reabrir
```

---

## Compatibilidade

| Distro | Versão mínima |
|---|---|
| Ubuntu | 22.04 |
| Debian | 11 (Bullseye) |
| Arquitetura | x86_64 apenas |

---

## O que é configurado automaticamente

| O que | Detalhe |
|---|---|
| Shell padrão | zsh com oh-my-zsh + powerlevel10k |
| Tema Windows Terminal | Moonlight II injetado direto no settings.json |
| Fonte Windows Terminal | MesloLGS NF instalada via PowerShell, sem admin |
| Perfil Ubuntu no Terminal | Fonte e tema já apontados para os corretos |
| Tema VS Code | Dracula gratuito instalado e ativado automaticamente |
| Extensão VS Code | Remote WSL instalada automaticamente |
| Grupo docker | Usuário adicionado (efetiva após logout/login) |
| Mirrored networking | `.wslconfig` configurado para compatibilidade com VPN e Boundary |

---

## Ferramentas instaladas

As ferramentas instaladas por releases externas ou instaladores oficiais usam a versão estável mais recente disponível no momento da execução. Pacotes instalados via `apt` usam a versão disponível nos repositórios configurados da distro.

### Terminal e shell

#### zsh + oh-my-zsh + powerlevel10k

O zsh é o shell principal. O oh-my-zsh adiciona plugins e temas. O powerlevel10k é o tema visual do terminal.

```bash
exec zsh        # inicia o wizard do powerlevel10k na primeira vez
p10k configure  # reconfigura o visual depois
```

Plugins ativos:

| Plugin | O que faz |
|---|---|
| `git` | Aliases e autocomplete para git |
| `docker` | Autocomplete para docker |
| `docker-compose` | Autocomplete para docker compose |
| `kubectl` | Autocomplete para kubectl |
| `terraform` | Autocomplete e aliases para Terraform |
| `zsh-autosuggestions` | Sugere comandos enquanto você digita |
| `zsh-syntax-highlighting` | Colore comandos válidos e inválidos |

### Linguagens e runtimes

#### Go

Instalado via site oficial. Útil para compilar ferramentas DevOps e desenvolver CLIs.

```bash
go version
go run main.go
go build -o meu-binario
go install github.com/algum/pacote@latest
go mod init meu-projeto
go mod tidy
```

#### Node.js + npm

Node.js LTS é instalado para suportar ferramentas distribuídas via npm, como `markdownlint-cli2`.

```bash
node --version
npm --version
npm install -g pacote-cli
```

#### Python + uv + pipx

Python vem com `pip`, `pipx` e `uv`. Use `uv` para projetos e `pipx` para instalar CLIs Python isoladas.

```bash
uv init meu-projeto
uv add requests
uv add --dev pytest
uv run python script.py
uv sync
pipx install black
pipx list
```

### Git e GitHub

#### git

```bash
gs              # git status
gc -m "msg"     # git commit
gp              # git push
git diff        # usa git-delta automaticamente
```

#### pre-commit

Intercepta commits e roda verificações automáticas no repositório.

```bash
pre-commit install
pre-commit run --all-files
pre-commit autoupdate
```

Exemplo de `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: detect-private-key
      - id: check-yaml
      - id: check-json
      - id: check-large-files
```

#### GitHub CLI (`gh`)

CLI oficial do GitHub. Dá para consultar repositórios públicos sem login, mas o uso completo exige `gh auth login`.

```bash
gh auth login
gh repo clone org/projeto
gh pr list
gh pr checkout 123
gh run list
```

#### git-delta

Melhora a leitura de diffs do git com cores, syntax highlight e modo lado a lado.

```bash
git diff
git show HEAD
delta arquivo.diff
```

### Containers

#### Docker

```bash
dcu                            # docker compose up -d
dcd                            # docker compose down
dcl                            # docker compose logs -f
docker ps
docker ps -a
docker images
docker exec -it <id> bash
docker system prune -af
```

### Infraestrutura como código

#### Terraform

Cria e gerencia infraestrutura usando arquivos `.tf`.

```bash
tf                    # terraform
tfi                   # terraform init
tfp                   # terraform plan
tfa                   # terraform apply
tfd                   # terraform destroy
terraform fmt
terraform validate
terraform state list
```

#### terraform-docs

Gera documentação automática para módulos Terraform.

```bash
terraform-docs markdown table .
terraform-docs markdown table --output-file README.md .
```

#### tflint

Linter para Terraform.

```bash
tflint
tflint --init
tflint --recursive
```

### Kubernetes local

#### kubectl

```bash
kgp
kgs
kgn
kubectl apply -f manifest.yaml
kubectl delete -f manifest.yaml
kubectl logs -f <pod>
kubectl exec -it <pod> -- bash
kubectl port-forward svc/meu-svc 8080:80
kubectl describe pod <pod>
```

#### kind

Cria clusters Kubernetes locais usando containers Docker.

```bash
kind create cluster --name dev
kind create cluster --name dev --config kind.yaml
kind get clusters
kind delete cluster --name dev
kind load docker-image minha-imagem:tag
```

Exemplo de `kind.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

#### Helm

Gerenciador de pacotes para Kubernetes.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx
helm install meu-nginx bitnami/nginx
helm upgrade meu-nginx bitnami/nginx --set replicaCount=2
helm list
helm uninstall meu-nginx
helm template meu-app ./chart
```

#### k9s

TUI interativa para gerenciar clusters Kubernetes.

```bash
k9s
k9s --context outro-cluster
k9s --namespace production
```

### Segredos

#### sops + age

Encripta arquivos de secrets para versionar no git com segurança. O setup usa `age` como caminho local e mantém exemplo de AWS KMS para produção.

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
sops --age age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx secrets.yaml

# Exemplo produtivo opcional: requer AWS CLI/credenciais configuradas fora deste setup
sops --kms arn:aws:kms:us-east-1:123456789:key/xxx secrets.yaml

sops secrets.yaml
sops -d secrets.yaml
```

### Qualidade, lint e segurança

#### Shell: shellcheck + shfmt

```bash
shellcheck script.sh
shellcheck -x script.sh
shfmt -w script.sh
shfmt -d .
```

#### YAML: yamllint + yq

```bash
yamllint arquivo.yaml
yamllint .
yq '.metadata.name' manifest.yaml
yq -i '.spec.replicas = 3' deployment.yaml
```

#### Python: ruff

```bash
ruff check .
ruff check --fix .
ruff format .
ruff check --select I --fix .
```

#### Dockerfile: hadolint

```bash
hadolint Dockerfile
hadolint --ignore DL3008 Dockerfile
```

#### Kubernetes: kubeconform

```bash
kubeconform manifest.yaml
kubeconform -summary .
kubeconform -kubernetes-version 1.29.0 manifest.yaml
```

#### GitHub Actions: actionlint

```bash
actionlint
actionlint .github/workflows/ci.yml
```

#### Markdown: markdownlint-cli2

```bash
markdownlint-cli2 README.md
markdownlint-cli2 "**/*.md"
```

#### Segurança: trivy

```bash
trivy image nginx:latest
trivy fs .
trivy config .
trivy image --severity HIGH,CRITICAL nginx:latest
```

### Utilitários de terminal

#### ripgrep (`rg`)

Busca texto em arquivos recursivamente. Muito mais rápido que o `grep`.

```bash
rg "texto"                  # busca no diretório atual
rg "texto" src/             # busca em pasta específica
rg -t py "def minha_func"   # só em arquivos .py
rg -l "TODO"                # lista arquivos com match
rg -i "texto"               # sem diferenciar maiúsculas
```

#### jq

Processa e extrai dados de JSON no terminal.

```bash
cat data.json | jq '.'                    # pretty print
cat data.json | jq '.nome'                # extrai campo
cat data.json | jq '.items[] | .nome'     # itera array
```

#### yq

Processa YAML, JSON e outros formatos estruturados direto no terminal. Muito útil para Kubernetes, Helm e GitHub Actions.

```bash
yq '.metadata.name' manifest.yaml
yq '.services.web.image' docker-compose.yaml
yq -i '.spec.replicas = 3' deployment.yaml
```

#### fzf

Busca interativa para arquivos, histórico e qualquer lista enviada por pipe.

```bash
fzf                              # seleciona arquivos interativamente
history | fzf                    # busca no histórico
git branch | fzf                 # escolhe uma branch visualmente
```

#### bat

Alternativa ao `cat` com syntax highlight. No Ubuntu/Debian o binário vem como `batcat`; o setup cria alias `cat='batcat --paging=never'`.

```bash
batcat README.md
cat README.md                    # usa batcat via alias no zsh
```

#### eza

Alternativa moderna ao `ls`, com melhor visualização de diretórios e árvores. O setup configura `ls`, `la` e `lt` como aliases.

```bash
ls                               # eza --group-directories-first
la                               # eza -la
lt                               # árvore em até 2 níveis
```

#### fd

Alternativa simples e rápida ao `find`. No Ubuntu/Debian o binário vem como `fdfind`; o setup cria alias `fd='fdfind'`.

```bash
fd Dockerfile
fd -e yaml
fd main src/
```

#### direnv

Carrega variáveis de ambiente automaticamente por diretório. Ideal para projetos com Terraform, Kubernetes local e stacks Docker.

```bash
echo 'export ENV=dev' > .envrc
direnv allow
echo "$ENV"
```

#### xh

Cliente HTTP para testar APIs direto no terminal.

```bash
xh get httpbin.org/get
xh post httpbin.org/post nome=João idade:=30
xh -A bearer -a meu-token get api.exemplo.com/users
xh -v get httpbin.org/get                # modo verbose
```

#### htop

Monitor de processos interativo.

```bash
htop
```

| Tecla | O que faz |
|---|---|
| `F5` | Alterna entre lista e árvore |
| `F6` | Ordena por coluna |
| `F9` | Mata o processo selecionado |
| `q` | Fecha |

#### tree

```bash
tree                           # árvore do diretório atual
tree -L 2                      # limita a 2 níveis
tree -I "node_modules|.git"    # ignora pastas
tree -a                        # inclui arquivos ocultos
```

#### dig / nslookup

```bash
dig google.com                 # consulta DNS
dig google.com +short          # só o IP
dig @8.8.8.8 google.com        # usa o DNS do Google
nslookup google.com
```

---

## WSL — Gerenciamento via PowerShell

Todos os comandos abaixo rodam no **PowerShell ou CMD do Windows**, não dentro do WSL.

#### Distros disponíveis e instalação

```powershell
wsl --list --online               # lista todas as distros disponíveis para instalar
wsl --install -d Ubuntu-26.04     # instala uma distro específica
wsl --update                      # atualiza o WSL para a versão mais recente
```

#### Gerenciar distros instaladas

```powershell
wsl --list --verbose              # lista as distros instaladas com status e versão WSL
wsl --list --running              # lista só as distros que estão rodando agora
wsl --set-default Ubuntu-26.04   # define a distro padrão ao rodar 'wsl' sem argumentos
wsl --set-version Ubuntu-26.04 2 # converte uma distro para WSL 2
```

#### Iniciar e parar

```powershell
wsl                               # abre a distro padrão
wsl -d Ubuntu-26.04               # abre uma distro específica
wsl --shutdown                    # para todas as distros e o WSL imediatamente
wsl -t Ubuntu-26.04               # para uma distro específica sem afetar as outras
```

#### Backup e restauração

```powershell
# Exporta a distro para um arquivo .tar — útil para backup ou migrar para outro PC
wsl --export Ubuntu-26.04 C:\backup\ubuntu-26.tar

# Importa uma distro a partir de um .tar
# wsl --import <nome> <pasta-de-instalação> <arquivo.tar>
wsl --import Ubuntu-26-backup C:\WSL\Ubuntu-26-backup C:\backup\ubuntu-26.tar

# Após importar, define o usuário padrão (substitua "weynne" pelo seu usuário)
wsl -d Ubuntu-26-backup -- bash -c "echo '[user]\ndefault=weynne' >> /etc/wsl.conf"
```

#### Remover uma distro

```powershell
# Atenção: remove a distro e todos os dados permanentemente
wsl --unregister Ubuntu-26.04
```

#### Acessar arquivos do WSL pelo Windows Explorer

```
\\wsl$\Ubuntu-26.04\home\<seu-usuario>
```

Cole esse caminho na barra de endereço do Explorer para navegar pelos arquivos da distro.
