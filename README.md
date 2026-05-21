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
├── setup-wsl.sh
└── dracula-pro.vsix   ← opcional (Pro pago); sem ele instala o Dracula gratuito
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
| Tema VS Code | Dracula Pro (se `.vsix` presente) ou Dracula gratuito |
| Extensão VS Code | Remote WSL instalada automaticamente |
| Grupo docker | Usuário adicionado (efetiva após logout/login) |
| Backup SSH | Chaves copiadas para `C:\Users\<user>\.ssh-backup-wsl` |
| Mirrored networking | `.wslconfig` configurado para compatibilidade com VPN e Boundary |

---

## Ferramentas instaladas

### 🐚 Shell

#### zsh + oh-my-zsh + powerlevel10k

O zsh é o shell principal. O oh-my-zsh adiciona plugins e temas. O powerlevel10k é o tema visual — mostra branch git, status do último comando, versão do Python/Node, etc.

Na primeira vez que abrir o terminal após o setup:

```bash
exec zsh   # inicia o wizard de configuração visual do powerlevel10k
p10k configure   # reconfigura o tema a qualquer momento
```

Plugins ativos:

| Plugin | O que faz |
|---|---|
| `git` | Aliases e autocomplete para git |
| `docker` | Autocomplete para docker |
| `docker-compose` | Autocomplete para docker compose |
| `kubectl` | Autocomplete para kubectl |
| `zsh-autosuggestions` | Sugere comandos enquanto você digita |
| `zsh-syntax-highlighting` | Colore o comando (verde = válido, vermelho = inválido) |

---

### 📝 Controle de versão

#### git

```bash
gs              # git status
gc -m "msg"     # git commit
gp              # git push
```

#### pre-commit

Intercepta cada `git commit` e roda verificações automáticas. Se algo estiver errado, o commit é bloqueado até você corrigir.

> **Importante:** rode `pre-commit install` uma vez dentro de cada repositório que quiser proteger.

```bash
pre-commit install            # ativa os hooks neste repositório
pre-commit run --all-files    # roda as verificações manualmente sem commitar
pre-commit autoupdate         # atualiza as versões dos hooks
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

---

### 🐹 Go

Instalado via site oficial sempre na versão estável mais recente. Essencial para DevOps — Docker, kubectl, kind e a maioria das ferramentas da stack são escritas em Go.

```bash
go version
go run main.go           # roda um arquivo Go diretamente
go build -o meu-binario  # compila o projeto
go install github.com/algum/pacote@latest  # instala uma ferramenta Go globalmente
go mod init meu-projeto  # inicia um novo módulo
go mod tidy              # sincroniza dependências
```

---

### 🐍 Python

#### uv

Gerenciador moderno de projetos e ambientes virtuais Python. Substitui o `python -m venv` + `pip install`.

```bash
uv init meu-projeto          # cria um novo projeto
uv add requests              # adiciona dependência (salva no pyproject.toml)
uv add --dev pytest          # dependência só de desenvolvimento
uv run python script.py      # roda dentro do ambiente virtual do projeto
uv sync                      # instala todas as dependências do pyproject.toml
```

#### pip

```bash
pip install requests
pip install -r requirements.txt
pip freeze > requirements.txt
```

#### pipx

Instala ferramentas CLI Python em ambientes isolados, sem misturar com o sistema.

```bash
pipx install black            # instala de forma isolada
pipx list                     # lista ferramentas instaladas
pipx upgrade-all              # atualiza tudo
pipx uninstall black          # desinstala
```

---


### 🏗️ Infraestrutura

#### Terraform

Cria e gerencia infraestrutura em cloud usando arquivos `.tf`. Você descreve o que quer ter e o Terraform descobre o que precisa criar, alterar ou destruir.

```bash
tf               # terraform
tfi              # terraform init — inicializa o projeto, baixa os providers — rode sempre ao clonar
tfp              # terraform plan — mostra o que será criado/alterado/destruído sem executar nada
tfa              # terraform apply — aplica as mudanças (pede confirmação)
tfd              # terraform destroy — destrói toda a infraestrutura gerenciada
terraform fmt        # formata os arquivos .tf
terraform validate   # valida a sintaxe sem precisar de credenciais cloud
terraform state list # lista recursos no state
```

#### AWS CLI

Interface de linha de comando para interagir com os serviços da AWS.

```bash
aws configure                                      # configura credenciais
aws sts get-caller-identity                        # confirma qual usuário/role está ativo
aws s3 ls                                          # lista buckets S3
aws s3 cp arquivo.txt s3://meu-bucket/             # upload de arquivo
aws ec2 describe-instances                         # lista instâncias EC2
aws logs tail /aws/lambda/minha-funcao --follow    # logs em tempo real
```

---

### 🐳 Docker

```bash
dcu                            # docker compose up -d
dcd                            # docker compose down
dcl                            # docker compose logs -f
docker ps                      # containers rodando
docker ps -a                   # todos, incluindo parados
docker images                  # imagens locais
docker exec -it <id> bash      # shell dentro do container
docker system prune -af        # limpa tudo que não está em uso
```

---

### ☸️ Kubernetes

#### kubectl

```bash
kgp                              # kubectl get pods
kgs                              # kubectl get svc
kgn                              # kubectl get nodes
kubectl apply -f manifest.yaml   # aplica um manifest no cluster
kubectl delete -f manifest.yaml  # remove os recursos do manifest
kubectl logs -f <pod>            # logs em tempo real
kubectl exec -it <pod> -- bash   # shell dentro do pod
kubectl port-forward svc/meu-svc 8080:80  # redireciona porta do cluster para localhost
kubectl describe pod <pod>       # detalhes e eventos — útil para debugar
```

#### kind — Kubernetes IN Docker

Cria clusters Kubernetes locais usando containers Docker. Ideal para desenvolvimento e testes sem precisar de cloud.

```bash
kind create cluster --name dev                     # cria um cluster
kind create cluster --name dev --config kind.yaml  # com configuração customizada
kind get clusters                                   # lista os clusters
kind delete cluster --name dev                     # remove o cluster
kind load docker-image minha-imagem:tag            # carrega imagem local no cluster
```

Exemplo de `kind.yaml` com 2 workers:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

#### Helm

Gerenciador de pacotes para Kubernetes. Instala aplicações no cluster usando charts prontos e configuráveis.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update                              # atualiza a lista de charts
helm search repo nginx                        # busca charts
helm install meu-nginx bitnami/nginx          # instala um chart
helm upgrade meu-nginx bitnami/nginx --set replicaCount=2
helm list                                     # lista instalações
helm uninstall meu-nginx                      # remove
helm template meu-app ./chart                 # renderiza manifests sem instalar
```

#### k9s

TUI interativa para gerenciar clusters Kubernetes direto no terminal.

```bash
k9s                              # abre com o contexto atual do kubectl
k9s --context outro-cluster      # abre em cluster específico
k9s --namespace production       # filtra por namespace
```

| Atalho | O que faz |
|---|---|
| `:pod` | Lista pods |
| `:svc` | Lista services |
| `:deploy` | Lista deployments |
| `l` | Logs do recurso selecionado |
| `e` | Edita o recurso |
| `d` | Describe o recurso |
| `ctrl+d` | Deleta o recurso |
| `/` | Filtra por nome |
| `?` | Ajuda |


### 🔐 Segredos

#### sops

Encripta arquivos de secrets para que possam ser versionados no git com segurança. Mantém a estrutura YAML/JSON legível — você vê os campos mas não os valores.

```bash
# Encripta um arquivo com AWS KMS
sops --kms arn:aws:kms:us-east-1:123456789:key/xxx secrets.yaml

# Edita o arquivo encriptado diretamente
sops secrets.yaml

# Decripta para stdout
sops -d secrets.yaml
```

---

### 🔍 Linters

#### shellcheck

Analisa scripts bash/sh e aponta erros, más práticas e problemas de portabilidade.

```bash
shellcheck script.sh               # analisa um script
shellcheck -x script.sh            # segue os `source` para analisar arquivos incluídos
shellcheck -S error script.sh      # mostra só erros, ignora avisos
```

#### yamllint

Valida sintaxe e estilo de arquivos YAML — Kubernetes, Docker Compose, GitHub Actions, etc.

```bash
yamllint arquivo.yaml              # valida um arquivo
yamllint .                         # valida todos os YAMLs do diretório atual
yamllint -d relaxed arquivo.yaml   # usa regras mais permissivas
```

#### ruff

Linter e formatter para Python. Substitui `flake8`, `black` e `isort` em um único comando, muito mais rápido que os três juntos.

```bash
ruff check .                       # analisa todos os arquivos Python
ruff check --fix .                 # corrige automaticamente o que for possível
ruff format .                      # formata os arquivos (equivale ao black)
ruff check --select I --fix .      # ordena imports (equivale ao isort)
```

#### tflint

Linter para Terraform. Pega erros que o `terraform validate` não detecta, como tipos de instância inválidos ou variáveis não declaradas.

```bash
tflint                             # analisa o diretório atual
tflint --init                      # instala plugins de providers (AWS, GCP, Azure)
tflint --recursive                 # analisa todos os módulos recursivamente
```

#### trivy

Scanner de segurança para imagens Docker, código IaC (Terraform, Kubernetes) e sistemas de arquivos.

```bash
trivy image nginx:latest           # escaneia uma imagem Docker
trivy fs .                         # escaneia o diretório atual (IaC, dependências)
trivy config .                     # analisa só arquivos de configuração IaC
trivy image --severity HIGH,CRITICAL nginx:latest  # filtra por severidade
```

#### hadolint

Linter para Dockerfile. Sugere boas práticas e aponta problemas comuns.

```bash
hadolint Dockerfile                # analisa um Dockerfile
hadolint --ignore DL3008 Dockerfile  # ignora uma regra específica
```

#### kubeconform

Valida manifests Kubernetes contra o schema oficial. Mais rápido e mantido que o `kubeval`.

```bash
kubeconform manifest.yaml          # valida um manifest
kubeconform -summary .             # valida todos os YAMLs e mostra resumo
kubeconform -kubernetes-version 1.29.0 manifest.yaml  # valida contra versão específica
```

---

### 🔧 Utilitários

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
