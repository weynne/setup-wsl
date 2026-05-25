# WSL DevOps Setup

Setup automatizado para WSL (Ubuntu 22.04+) com ferramentas de desenvolvimento e DevOps.

---

## Como usar

### Passo 1 — Instale o WSL no Windows

Abra o **PowerShell como administrador** e rode:

```powershell
wsl --install
```

Reinicie o computador quando solicitado. Na primeira abertura do WSL, crie seu usuário e senha.

---

### Passo 2 — Instale o VS Code no Windows (Se ainda não tiver)

Baixe em [code.visualstudio.com](https://code.visualstudio.com) e durante a instalação marque a opção **"Add to PATH"**. Isso é necessário para o script instalar as extensões automaticamente.

---

### Passo 3 — Instale o Windows Terminal (Se ainda não tiver)

Baixe na [Microsoft Store](https://aka.ms/terminal). O script configura o tema Moonlight II e a fonte automaticamente.

---

### Passo 4 — Baixe o setup

No WSL, clone este repositório:

```bash
cd ~
git clone https://github.com/weynne/setup-wsl.git
cd setup-wsl
```

---

### Passo 5 — Rode o script

Abra o WSL, navegue até a pasta e execute:

```bash
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

### Base Linux

#### Pacotes essenciais

Ferramentas base para baixar arquivos, verificar assinaturas, compilar dependências e lidar com arquivos compactados.

**curl** — transferência de dados por HTTP/HTTPS/FTP, a ferramenta mais usada em scripts de instalação e CI/CD:

```bash
curl -fsSL https://exemplo.com/arquivo.txt -o arquivo.txt   # download silencioso
curl -fsSL https://exemplo.com/script.sh | bash              # pipe direto para execução
curl -I https://exemplo.com                                  # só os headers HTTP
curl -o /dev/null -s -w "%{http_code}" https://exemplo.com  # só o status code
curl -u usuario:senha https://api.exemplo.com/recurso        # basic auth
```

**wget** — download de arquivos e mirrors recursivos:

```bash
wget https://exemplo.com/arquivo.zip
wget -q -O arquivo.zip https://exemplo.com/arquivo.zip      # silencioso com nome definido
wget -r -np https://exemplo.com/docs/                       # download recursivo
wget -c https://exemplo.com/arquivo.iso                     # retoma download interrompido
```

**tar / unzip** — compactação e extração de arquivos:

```bash
tar -xzf arquivo.tar.gz                  # extrai .tar.gz
tar -xzf arquivo.tar.gz -C /destino/    # extrai em pasta específica
tar -czf backup.tar.gz ./pasta/         # cria arquivo compactado
tar -tzf arquivo.tar.gz                 # lista conteúdo sem extrair
unzip arquivo.zip
unzip arquivo.zip -d /destino/
unzip -l arquivo.zip                    # lista conteúdo sem extrair
```

**gpg** — verificação de assinaturas e gerenciamento de chaves de repositórios APT:

```bash
gpg --version
gpg --import chave.asc                                        # importa chave pública
gpg --verify arquivo.sig arquivo                              # verifica assinatura
gpg --fingerprint email@exemplo.com                           # exibe fingerprint da chave
curl -fsSL https://repo.exemplo.com/gpg | gpg --dearmor \
  | sudo tee /usr/share/keyrings/repo.gpg > /dev/null        # adiciona chave para apt
```

**lsb_release / /etc/os-release** — identifica a distribuição, útil em scripts de setup:

```bash
lsb_release -a                          # informações completas da distro
lsb_release -cs                         # só o codename (ex: noble, jammy)
cat /etc/os-release                     # arquivo de referência usado pelo script
```

#### Build tools

`gcc` e `make` são dependências de compilação usadas por extensões nativas de Python, módulos npm, Neovim plugins e diversas CLIs que não distribuem binários pré-compilados.

```bash
gcc --version
gcc -o programa programa.c              # compila um arquivo C
gcc -O2 -o programa programa.c         # com otimização

make --version
make                                    # executa o alvo padrão do Makefile
make build                             # alvo específico
make clean                             # limpa artefatos de build
make -n build                          # dry-run — mostra o que executaria
make -j4                               # paraleliza em 4 threads
```

**Em produção:** dependências indiretas — raramente usadas diretamente, mas necessárias para `pip install` de pacotes com extensões C, `npm install` de módulos nativos e compilação de plugins do Neovim.

#### Rede

Ferramentas para inspecionar interfaces, rotas, conexões e DNS dentro do WSL — essenciais para debug de conectividade e configuração de rede.

**ip** — inspeciona e configura interfaces e rotas:

```bash
ip addr                                 # lista interfaces e IPs
ip addr show eth0                      # interface específica
ip route                               # tabela de rotas
ip route show default                  # só o gateway padrão
ip link show                           # estado das interfaces (UP/DOWN)
```

**ss** — substituto moderno do `netstat`, mostra conexões e portas abertas:

```bash
ss -tulpn                              # todas as portas em escuta (TCP+UDP) com processos
ss -tlnp                               # só TCP
ss -s                                  # resumo de estatísticas
ss -tp                                 # conexões TCP ativas com processos
```

**dig / nslookup** — consultas DNS, úteis para debug de resolução de nomes no WSL:

```bash
dig google.com                         # consulta DNS completa
dig google.com +short                  # só o IP
dig google.com A                       # registro A (IPv4)
dig google.com AAAA                    # registro AAAA (IPv6)
dig google.com MX                      # servidores de e-mail
dig @8.8.8.8 google.com               # força uso do DNS do Google
dig @1.1.1.1 google.com +short        # DNS da Cloudflare
nslookup google.com
nslookup google.com 8.8.8.8           # com DNS específico
```

**Em produção:** `ss -tulpn` para verificar se uma porta está em uso antes de subir um serviço; `dig` para validar propagação de DNS após mudança de registros.

### Terminal e shell

#### zsh + oh-my-zsh + powerlevel10k

O zsh é o shell principal. O oh-my-zsh adiciona plugins e temas. O powerlevel10k é o tema visual do terminal com informações de git, contexto Kubernetes, tempo de execução de comandos e muito mais.

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
| `kubectl` | Autocomplete para kubectl (com cache) |
| `helm` | Autocomplete para helm (com cache) |
| `terraform` | Autocomplete e aliases para Terraform |
| `zsh-autosuggestions` | Sugere comandos enquanto você digita baseado no histórico |
| `zsh-syntax-highlighting` | Colore comandos válidos em verde e inválidos em vermelho em tempo real |

#### tmux

Multiplexador de terminal — mantém sessões persistentes no WSL, útil para trabalhar com múltiplos painéis ou reconectar a sessões em andamento. Essencial ao trabalhar via SSH em servidores remotos.

```bash
tmux                         # nova sessão
tmux new -s dev              # nova sessão com nome
tmux ls                      # lista sessões ativas
tmux attach -t dev           # reconecta à sessão "dev"
```

| Atalho | O que faz |
|---|---|
| `Ctrl+b c` | Nova janela |
| `Ctrl+b "` | Divide horizontal |
| `Ctrl+b %` | Divide vertical |
| `Ctrl+b d` | Desconecta (sessão continua rodando) |
| `Ctrl+b [` | Modo scroll |

**Em produção:** indispensável ao trabalhar via SSH em servidores. Permite iniciar um processo longo, desconectar e reconectar mais tarde sem perder o estado.

### Linguagens e runtimes

#### Go

Instalado via site oficial. Go é a linguagem principal do ecossistema cloud-native — kubectl, Terraform, Helm, k9s, e a maioria das ferramentas DevOps são escritas em Go. Ter o runtime instalado permite compilar ferramentas customizadas, escrever operators Kubernetes, CLIs internas e providers Terraform.

```bash
go version
go run main.go
go build -o meu-binario
go install github.com/algum/pacote@latest
go mod init meu-projeto
go mod tidy
```

**Em produção:** base para escrever Kubernetes operators, controllers customizados e providers Terraform internos.

#### Node.js + npm

Node.js LTS instalado via NodeSource. Suporta ferramentas distribuídas via npm (`markdownlint-cli2`), além de ser runtime de ferramentas como AWS CDK e Serverless Framework.

```bash
node --version
npm --version
npm install -g pacote-cli
```

#### Python + uv + pipx

Python instalado via apt. `uv` é o gerenciador de projetos e ambientes virtuais (mais rápido que pip/venv). `pipx` instala CLIs Python em ambientes isolados sem poluir o sistema.

```bash
# Projetos Python
uv init meu-projeto
uv add requests
uv add --dev pytest
uv run python script.py
uv sync

# CLIs isoladas
pipx install black
pipx list
```

**Em produção:** `uv` para gerenciar dependências de scripts de automação e lambdas Python. `pipx` para instalar ferramentas de qualidade de código sem conflito de versões.

### Git e GitHub

#### git

Configurado com `git-delta` para diffs coloridos com syntax highlight, `main` como branch padrão e VS Code como editor.

```bash
gs              # git status
gc -m "msg"     # git commit
gp              # git push
git diff        # usa git-delta automaticamente
git log --oneline --graph
```

#### pre-commit

Intercepta commits locais e roda verificações automáticas antes de permitir o commit. Garante que código com problemas não entre no repositório.

```bash
pre-commit install          # ativa os hooks no repositório atual
pre-commit run --all-files  # roda manualmente em todos os arquivos
pre-commit autoupdate       # atualiza versões dos hooks
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
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
```

**Em produção:** combine com CI/CD para rodar os mesmos checks no pipeline, garantindo que PRs sem pre-commit instalado também sejam verificados.

#### GitHub CLI (`gh`)

CLI oficial do GitHub. Permite criar PRs, revisar issues, fazer checkout de branches e consultar runs de Actions sem sair do terminal.

```bash
gh auth login
gh repo clone org/projeto
gh pr list
gh pr create --title "feat: nova feature" --body "descrição"
gh pr checkout 123
gh pr merge 123 --squash
gh run list
gh run view 123 --log
gh run watch              # aguarda o run atual terminar
gh secret set MINHA_VAR  # define secret no repositório
```

**Em produção:** automação de workflows — criar PRs automaticamente após deploys, monitorar runs de CI, gerenciar secrets de repositório.

#### git-delta

Substitui o pager padrão do git com syntax highlight, numeração de linhas e modo lado a lado. Configurado automaticamente no `~/.gitconfig`.

```bash
git diff
git show HEAD
git log -p
delta arquivo.diff         # diff de arquivo externo
```

#### lazygit

TUI completa para Git no terminal — staging por hunk, rebase interativo, cherry-pick e gestão de branches, tudo sem digitar comandos git.

```bash
lazygit
lazygit -p /caminho/do/repositorio
```

| Tecla | O que faz |
|---|---|
| `space` | Faz stage/unstage de arquivo ou hunk |
| `c` | Commit |
| `P` | Push |
| `p` | Pull |
| `b` | Gerencia branches |
| `r` | Rebase interativo |
| `?` | Ajuda completa |

**Em produção:** útil para revisão de diffs complexos, rebase interativo e cherry-pick de commits em hotfixes.

#### task (Taskfile)

Alternativa moderna ao `make` com sintaxe YAML mais legível e portável. Muito usado em projetos DevOps para centralizar comandos de build, deploy e validação.

```bash
task                         # lista tarefas disponíveis
task build                   # executa a tarefa "build"
task deploy ENV=production   # passa variáveis
task --list-all              # lista incluindo tarefas internas
```

Exemplo de `Taskfile.yml`:

```yaml
version: '3'

tasks:
  lint:
    desc: Roda todos os linters
    cmds:
      - tflint
      - checkov -d .
      - hadolint Dockerfile

  build:
    desc: Build da imagem Docker
    cmds:
      - docker build -t minha-app:{{.TAG}} .

  deploy:
    desc: Aplica manifests no cluster
    cmds:
      - kubectl apply -f k8s/
      - kubectl rollout status deployment/minha-app
```

**Em produção:** substitui scripts `Makefile` em repositórios de infraestrutura — mais legível, sem problemas de tab vs espaço, com suporte a dependências entre tasks e variáveis de ambiente.

### Editor de terminal

#### Neovim + LazyVim

Neovim é instalado pela release oficial mais recente. LazyVim é instalado a partir do starter oficial em `~/.config/nvim` quando ainda não existe configuração do Neovim. Inclui LSP, autocomplete, fuzzy finder, tree-sitter e integração com lazygit.

```bash
nvim
nvim README.md
nvim .             # abre a pasta atual como projeto
```

Se `~/.config/nvim` já existir, o setup não sobrescreve sua configuração.

Comandos básicos:

| Comando | O que faz |
|---|---|
| `nvim` | Abre o Neovim |
| `nvim README.md` | Abre um arquivo direto |
| `nvim .` | Abre a pasta atual como projeto |
| `<Space>ff` | Busca arquivos |
| `<Space>fg` | Busca texto no projeto |
| `<Space>e` | Abre ou fecha o explorer |
| `<Space>gg` | Abre o lazygit |
| `:Lazy` | Gerencia plugins |
| `:Mason` | Gerencia LSPs, formatters e linters |
| `:LazyHealth` | Verifica a saúde da instalação |
| `:w` | Salva o arquivo |
| `:q` | Sai |
| `:wq` | Salva e sai |

**Em produção:** edição de arquivos em servidores via SSH onde VS Code não está disponível. Com LazyVim, o nvim tem LSP e autocomplete para HCL, YAML, Go e Python.

### Containers

#### Docker

Engine de containers instalada via repositório oficial. O usuário é adicionado ao grupo `docker` automaticamente (efetiva após relogin).

```bash
dcu                            # docker compose up -d
dcd                            # docker compose down
dcl                            # docker compose logs -f
ld                             # lazydocker (TUI)
docker ps
docker ps -a
docker images
docker exec -it <id> bash
docker logs -f <id>
docker system prune -af        # limpa tudo não utilizado
```

**Em produção:** builds multi-stage para imagens enxutas, integração com ECR/GCR para push de imagens em pipelines CI/CD.

```dockerfile
# Exemplo: multi-stage build para imagem mínima
FROM golang:1.26 AS builder
WORKDIR /app
COPY . .
RUN go build -o app .

FROM gcr.io/distroless/static
COPY --from=builder /app/app /app
CMD ["/app"]
```

#### lazydocker

TUI interativa para gerenciar containers, imagens, volumes e logs do Docker sem precisar lembrar flags de comandos.

```bash
ld                             # alias para lazydocker
```

| Tecla | O que faz |
|---|---|
| `←` / `→` | Navega entre painéis |
| `↑` / `↓` | Seleciona item |
| `enter` | Abre detalhes / logs |
| `d` | Remove container/imagem |
| `s` | Para/inicia container |
| `?` | Ajuda com todos os atalhos |

#### dive

Inspeciona camada por camada de uma imagem Docker para identificar o que está aumentando o tamanho desnecessariamente. Fundamental para otimizar imagens antes de publicar em produção.

```bash
dive nginx:latest
dive minha-imagem:tag
dive build --tag minha-imagem:tag .   # build + analisa direto
```

**Em produção:** use no pipeline CI para garantir que imagens não ultrapassem um limite de tamanho ou contenham arquivos desnecessários (caches de build, credenciais acidentais).

### Cloud

#### AWS CLI

Interface de linha de comando para todos os serviços da AWS. Essencial para gerenciar infraestrutura, credenciais temporárias, buckets S3, clusters EKS, repositórios ECR e segredos direto do terminal.

**Configuração inicial:**

```bash
aws configure                          # configura credenciais interativamente
aws configure --profile staging        # perfil nomeado por ambiente
aws configure list                     # mostra configuração ativa
aws configure list-profiles            # lista todos os perfis
```

Ou via variáveis de ambiente (recomendado em CI/CD e containers):

```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
```

**Identidade e conta:**

```bash
aws sts get-caller-identity            # mostra conta, usuário e ARN atual
aws sts assume-role \
  --role-arn arn:aws:iam::123:role/Deploy \
  --role-session-name deploy-session   # assume role com permissões temporárias
```

**S3:**

```bash
aws s3 ls                              # lista buckets
aws s3 ls s3://meu-bucket/            # lista conteúdo
aws s3 cp arquivo.txt s3://bucket/    # upload
aws s3 sync ./dist s3://bucket/site   # sincroniza diretório inteiro
aws s3 rm s3://bucket/arquivo.txt
```

**EKS:**

```bash
aws eks list-clusters
aws eks update-kubeconfig \
  --name meu-cluster \
  --region us-east-1                   # adiciona cluster ao kubeconfig local
aws eks describe-cluster --name meu-cluster
```

**ECR:**

```bash
# Login no registry privado
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS \
    --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com

aws ecr describe-repositories
aws ecr list-images --repository-name meu-repo
```

**Segredos:**

```bash
# SSM Parameter Store
aws ssm get-parameter --name "/app/prod/db-password" --with-decryption
aws ssm put-parameter \
  --name "/app/prod/db-password" \
  --value "minha-senha" \
  --type SecureString

# Secrets Manager
aws secretsmanager get-secret-value --secret-id meu-segredo
aws secretsmanager list-secrets
```

**Em produção:**

```bash
# Múltiplos ambientes com perfis nomeados
aws s3 ls --profile staging
terraform apply --var-file=prod.tfvars  # Terraform usa o perfil configurado no provider

# CI/CD com OIDC (sem access key permanente — recomendado)
# GitHub Actions: aws-actions/configure-aws-credentials com role-to-assume
# EKS: IAM Roles for Service Accounts (IRSA) — a pod recebe credenciais temporárias
#      via metadata endpoint sem nenhuma chave no código
```

Integração direta com Terraform:

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "production"   # usa perfil do ~/.aws/credentials
}
```

### Infraestrutura como código

#### Terraform

Provisiona e gerencia infraestrutura em qualquer cloud usando arquivos `.tf` declarativos. Instalado via repositório oficial HashiCorp.

```bash
tf                    # terraform (alias)
tfi                   # terraform init
tfp                   # terraform plan
tfa                   # terraform apply
tfd                   # terraform destroy
terraform fmt         # formata arquivos .tf
terraform validate    # valida sintaxe e configuração
terraform state list  # lista recursos no state
terraform output      # exibe outputs do módulo
```

**Em produção:**

```bash
# State remoto com S3 + DynamoDB (lock de concorrência)
# backend.tf:
# terraform {
#   backend "s3" {
#     bucket         = "meu-tfstate"
#     key            = "prod/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-lock"
#     encrypt        = true
#   }
# }

# Workspaces para múltiplos ambientes
terraform workspace new staging
terraform workspace select production
terraform workspace list

# Workflow de produção seguro
terraform plan -out=tfplan          # gera plano e salva
terraform show tfplan               # revisa o plano
terraform apply tfplan              # aplica exatamente o plano revisado
```

#### terraform-docs

Gera documentação automática para módulos Terraform a partir dos `variable`, `output` e `resource` definidos.

```bash
terraform-docs markdown table .
terraform-docs markdown table --output-file README.md .  # atualiza README do módulo
```

**Em produção:** integre com pre-commit para manter a documentação dos módulos sempre atualizada automaticamente:

```yaml
- repo: https://github.com/terraform-docs/gh-actions
  hooks:
    - id: terraform-docs-go
      args: ["--output-file", "README.md", "."]
```

#### tflint

Linter para Terraform — detecta erros de configuração, tipos incorretos e práticas ruins que o `terraform validate` não pega.

```bash
tflint
tflint --init          # instala plugins de provider (ex: aws, google)
tflint --recursive     # roda em todos os módulos do repositório
```

**Em produção:** adicione ao pipeline CI antes do `terraform plan` para bloquear configurações inválidas antes de elas chegarem ao state.

### Kubernetes local

#### kubectl

CLI principal para interagir com qualquer cluster Kubernetes — local (kind) ou produção (EKS, GKE, AKS).

```bash
kgp                                    # kubectl get pods
kgs                                    # kubectl get svc
kgn                                    # kubectl get nodes
kctx                                   # troca de contexto
kns                                    # troca de namespace
kubectl apply -f manifest.yaml
kubectl delete -f manifest.yaml
kubectl logs -f <pod>
kubectl logs -f <pod> -c <container>   # container específico
kubectl exec -it <pod> -- bash
kubectl port-forward svc/meu-svc 8080:80
kubectl describe pod <pod>
kubectl get events --sort-by='.lastTimestamp'
kubectl rollout status deployment/meu-app
kubectl rollout undo deployment/meu-app  # rollback
```

**Em produção:**

```bash
# Conectar ao cluster EKS
aws eks update-kubeconfig --name prod-cluster --region us-east-1

# Debug de pod com crash loop
kubectl describe pod <pod>                        # eventos e status
kubectl logs <pod> --previous                     # logs do container anterior
kubectl debug <pod> -it --image=busybox           # container de debug

# Escalar deployment
kubectl scale deployment meu-app --replicas=5

# Verificar recursos consumidos
kubectl top pods
kubectl top nodes
```

#### kind

Cria clusters Kubernetes locais usando containers Docker como nós. Ideal para desenvolvimento, testes de manifests e CI/CD. **Não é usado em produção** — em produção use EKS (AWS), GKE (GCP) ou AKS (Azure).

```bash
kind create cluster --name dev
kind create cluster --name dev --config kind.yaml
kind get clusters
kind delete cluster --name dev
kind load docker-image minha-imagem:tag    # carrega imagem local no cluster
```

Exemplo de `kind.yaml` com múltiplos nós:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

**Em CI/CD:** use kind para rodar testes de integração com Kubernetes real em pipelines GitHub Actions sem precisar de um cluster externo.

#### Helm

Gerenciador de pacotes para Kubernetes — empacota, versiona e instala aplicações como charts reutilizáveis.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx
helm install meu-nginx bitnami/nginx
helm upgrade meu-nginx bitnami/nginx --set replicaCount=2
helm list
helm uninstall meu-nginx
helm template meu-app ./chart              # renderiza sem instalar
helm diff upgrade meu-app ./chart          # mostra o que vai mudar (plugin)
```

**Em produção:**

```bash
# Values por ambiente
helm upgrade --install meu-app ./chart \
  -f values.yaml \
  -f values-production.yaml \
  --set image.tag=${GIT_SHA} \
  --atomic \               # rollback automático se falhar
  --timeout 5m

# Ver histórico de releases
helm history meu-app
helm rollback meu-app 3    # rollback para revisão 3
```

#### k9s

TUI interativa para gerenciar clusters Kubernetes — navega por pods, logs, describes e executa comandos sem digitar kubectl.

```bash
k9s
k9s --context outro-cluster
k9s --namespace production
```

| Tecla | O que faz |
|---|---|
| `:pod` | Lista pods (qualquer recurso pelo tipo) |
| `l` | Abre logs do pod |
| `s` | Abre shell no container |
| `d` | Describe do recurso |
| `ctrl+d` | Deleta o recurso |
| `ctrl+k` | Kill (força deleção) |
| `/` | Filtra por nome |
| `?` | Ajuda completa |

**Em produção:** debug em tempo real de pods com crash, inspeção de logs de múltiplos containers e gerenciamento de recursos sem decorar flags do kubectl.

#### kubectx + kubens

Troca de contexto e namespace do Kubernetes com um único comando. Indispensável ao trabalhar com múltiplos clusters.

```bash
kctx                           # lista contextos disponíveis
kctx meu-cluster               # troca para o contexto "meu-cluster"
kctx -                         # volta para o contexto anterior
kns                            # lista namespaces disponíveis
kns production                 # troca para o namespace "production"
kns -                          # volta para o namespace anterior
```

**Em produção:** evita o erro clássico de rodar `kubectl delete` no cluster errado por descuido. Torna a troca entre dev/staging/prod explícita e rápida.

#### stern

Faz tail de logs de múltiplos pods ao mesmo tempo com filtros por label, namespace ou regex — essencial para debug de aplicações distribuídas.

```bash
stern meu-app                          # todos os pods com "meu-app" no nome
stern -n production meu-app            # em namespace específico
stern -l app=api                       # por label selector
stern "frontend|backend"               # múltiplos apps via regex
stern meu-app --since 5m               # só os últimos 5 minutos
stern meu-app -c meu-container         # container específico
stern meu-app --exclude "healthcheck"  # filtra linhas por regex
```

**Em produção:** acompanhar logs de todos os pods de um deployment durante um deploy ou incidente sem abrir uma aba por pod.

### Segredos

#### sops + age

`sops` encripta arquivos de secrets para versionar no git com segurança. `age` é o backend de criptografia recomendado para uso local e em equipe.

```bash
# Gerar chave age
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# Encriptar e editar secrets
sops --age age1xxxx secrets.yaml  # cria/edita arquivo encriptado
sops secrets.yaml                  # abre no editor para editar
sops -d secrets.yaml               # decripta para stdout

# Ver sem editar
sops -d secrets.yaml | yq '.database.password'
```

**Em produção:**

```bash
# .sops.yaml na raiz do repositório define quem pode decriptar
# creation_rules:
#   - path_regex: environments/prod/.*
#     kms: arn:aws:kms:us-east-1:123456789:key/xxx  # chave KMS para prod
#   - path_regex: environments/dev/.*
#     age: age1xxxx,age1yyyy                          # chaves age da equipe

# CI/CD com AWS KMS — sem chave privada no pipeline
sops --kms arn:aws:kms:us-east-1:123456789:key/xxx secrets.yaml
sops -d secrets.yaml | kubectl apply -f -            # decripta e aplica

# Múltiplos destinatários (toda a equipe pode decriptar)
sops --age age1dev,age1ops secrets.yaml
```

### Qualidade, lint e segurança

#### Shell: shellcheck + shfmt

`shellcheck` detecta erros e armadilhas em scripts bash/sh. `shfmt` formata scripts shell de forma consistente.

```bash
shellcheck script.sh
shellcheck -x script.sh              # segue source/includes
shfmt -w script.sh                   # formata in-place
shfmt -d .                           # mostra diff sem alterar
shfmt -l .                           # lista arquivos não formatados
```

**Em produção:** add ao pre-commit e CI para garantir que scripts de automação não têm bugs silenciosos (variáveis sem aspas, condições incorretas, etc).

#### YAML: yamllint

Valida sintaxe e estilo de arquivos YAML — Kubernetes manifests, GitHub Actions, docker-compose.

```bash
yamllint arquivo.yaml
yamllint .                           # todos os YAMLs do diretório
yamllint -d relaxed .                # modo menos restritivo
```

**Em produção:** essencial em repositórios de infraestrutura onde um YAML inválido pode quebrar um deploy inteiro.

#### Python: ruff

Linter e formatter Python extremamente rápido — substitui flake8, isort, black e pylint com uma única ferramenta.

```bash
ruff check .
ruff check --fix .                   # corrige automaticamente
ruff format .                        # formata código
ruff check --select I --fix .        # só imports (equivalente ao isort)
```

**Em produção:** add ao pre-commit para garantir código Python consistente em scripts de automação e lambdas.

#### Dockerfile: hadolint

Linter para Dockerfiles — detecta práticas ruins que geram imagens inseguras, grandes ou não-reproduzíveis.

```bash
hadolint Dockerfile
hadolint --ignore DL3008 Dockerfile  # ignora regra específica
hadolint --format json Dockerfile    # output para parsear em CI
```

**Em produção:** bloqueia no CI Dockerfiles que usam `latest`, instalam pacotes sem versão fixada ou executam como root.

#### Kubernetes: kubeconform

Valida manifests Kubernetes contra os schemas oficiais da API — pega campos inválidos e versões de API depreciadas antes de aplicar no cluster.

```bash
kubeconform manifest.yaml
kubeconform -summary .
kubeconform -kubernetes-version 1.29.0 manifest.yaml
kubeconform -strict manifest.yaml    # falha em campos desconhecidos
```

**Em produção:** adicione ao pipeline CI para validar todos os manifests antes de qualquer `kubectl apply` ou `helm upgrade`.

#### GitHub Actions: actionlint

Linter para workflows do GitHub Actions — detecta erros de sintaxe, expressões inválidas e problemas de segurança (ex: injection via `${{ github.event.pull_request.title }}`).

```bash
actionlint
actionlint .github/workflows/ci.yml
actionlint -format '{{range $e := .}}{{$e.Filepath}}:{{$e.Line}}: {{$e.Message}}\n{{end}}'
```

**Em produção:** evita workflows quebrados em produção e detecta vulnerabilidades de injeção em GitHub Actions.

#### Markdown: markdownlint-cli2

Linta arquivos Markdown contra regras de estilo e consistência — READMEs, runbooks e documentação de infraestrutura.

```bash
markdownlint-cli2 README.md
markdownlint-cli2 "**/*.md"
markdownlint-cli2 --fix "**/*.md"    # corrige automaticamente
```

#### Segurança de containers e IaC: trivy

Scanner de segurança completo — vulnerabilidades em imagens Docker, dependências de código, configurações IaC e secrets em arquivos.

```bash
trivy image nginx:latest
trivy image --severity HIGH,CRITICAL nginx:latest
trivy fs .                           # filesystem local (deps, IaC, secrets)
trivy config .                       # só configurações IaC
trivy repo github.com/org/repo       # repositório remoto
```

**Em produção:** integre ao pipeline CI para bloquear deploys de imagens com vulnerabilidades críticas:

```yaml
# GitHub Actions
- name: Scan image
  run: trivy image --exit-code 1 --severity CRITICAL minha-imagem:${{ github.sha }}
```

#### Segurança de repositório: gitleaks

Detecta segredos (tokens, passwords, chaves API) commitados acidentalmente no histórico ou arquivos do repositório.

```bash
gitleaks detect                      # escaneia o repositório atual
gitleaks detect --source .           # diretório específico
gitleaks protect --staged            # escaneia só o que está em stage
gitleaks detect --report-path report.json
```

Integração com pre-commit:

```yaml
- repo: https://github.com/gitleaks/gitleaks
  rev: v8.30.1
  hooks:
    - id: gitleaks
```

**Em produção:** rode `gitleaks detect` no pipeline CI para escanear o histórico completo de novos repositórios e PRs antes de merge.

#### IaC multi-plataforma: checkov

Analisa arquivos Terraform, Kubernetes, Dockerfiles e GitHub Actions contra benchmarks de segurança (CIS, NIST). Mais abrangente que o `tflint` — foca em riscos de segurança em múltiplas plataformas.

```bash
checkov -d .                         # escaneia o diretório atual
checkov -f main.tf                   # arquivo específico
checkov -d . --framework terraform
checkov -d . --framework kubernetes
checkov -d . --framework dockerfile
checkov -d . --framework github_actions
checkov -d . --check CKV_AWS_18      # check específico
checkov -d . --skip-check CKV2_AWS_5 # ignora check
checkov -d . --output json           # saída para CI
```

**Em produção:** adicione ao pipeline CI após o `terraform plan` para bloquear configurações que violam políticas de segurança da empresa antes do `apply`.

### Utilitários de terminal

#### ripgrep (`rg`)

Busca texto em arquivos recursivamente com suporte a `.gitignore`. Muito mais rápido que `grep` e com output colorido.

```bash
rg "texto"                   # busca no diretório atual
rg "texto" src/              # pasta específica
rg -t py "def minha_func"    # só em arquivos .py
rg -l "TODO"                 # lista arquivos com match
rg -i "texto"                # case-insensitive
rg -n "pattern"              # mostra números de linha
rg --hidden "texto"          # inclui arquivos ocultos
```

#### jq

Processa e extrai dados de JSON no terminal. Indispensável para trabalhar com respostas de APIs, AWS CLI e outputs de ferramentas DevOps.

```bash
cat data.json | jq '.'                         # pretty print
cat data.json | jq '.nome'                     # extrai campo
cat data.json | jq '.items[] | .nome'          # itera array
cat data.json | jq 'select(.status == "ok")'   # filtra por valor
cat data.json | jq '{nome: .name, id: .id}'    # reshape do objeto

# Uso com AWS CLI
aws ec2 describe-instances | jq '.Reservations[].Instances[] | {id: .InstanceId, state: .State.Name}'
aws s3api list-buckets | jq '.Buckets[].Name'
```

**Em produção:** parsear outputs do AWS CLI, APIs REST e respostas de webhooks em scripts de automação.

#### yq

Processa YAML, JSON e outros formatos estruturados — equivalente ao `jq` para YAML. Muito útil para Kubernetes, Helm values e GitHub Actions.

```bash
yq '.metadata.name' manifest.yaml
yq '.services.web.image' docker-compose.yaml
yq -i '.spec.replicas = 3' deployment.yaml       # edita in-place
yq -i '.image.tag = env(TAG)' values.yaml        # usa variável de ambiente
yq eval-all 'select(.kind == "Deployment")' *.yaml  # filtra por tipo
```

**Em produção:** atualizar `image.tag` em values do Helm durante pipelines de deploy sem precisar de sed/awk.

#### fzf

Busca interativa fuzzy para qualquer lista — histórico de comandos, arquivos, branches, processos.

```bash
fzf                               # seleciona arquivos
history | fzf                     # busca no histórico
git branch | fzf                  # escolhe branch visualmente
ps aux | fzf                      # seleciona processo
kubectl get pods | fzf            # seleciona pod
```

Integrado ao shell: `Ctrl+R` para histórico interativo, `Ctrl+T` para arquivos, `Alt+C` para diretórios.

#### bat

Alternativa ao `cat` com syntax highlight e integração com git. No Ubuntu/Debian o binário vem como `batcat`; o setup cria alias `cat='batcat --paging=never'`.

```bash
batcat README.md
cat README.md              # usa batcat via alias no zsh
bat -l yaml manifest.yaml  # força linguagem
bat --diff arquivo.py      # mostra diff com git
```

#### eza

Alternativa moderna ao `ls` com cores, ícones e visualização de árvore. O setup configura `ls`, `la` e `lt` como aliases.

```bash
ls                         # eza --group-directories-first
la                         # eza -la (com permissões e datas)
lt                         # árvore em até 2 níveis
eza --git                  # mostra status git por arquivo
eza -la --sort=modified    # ordena por data de modificação
```

#### fd

Alternativa simples e rápida ao `find` com sintaxe mais intuitiva e respeito ao `.gitignore`. No Ubuntu/Debian o binário vem como `fdfind`; o setup cria alias `fd='fdfind'`.

```bash
fd Dockerfile
fd -e yaml                 # por extensão
fd main src/               # nome dentro de pasta
fd -t d node_modules       # só diretórios
fd --hidden .env           # inclui arquivos ocultos
```

#### direnv

Carrega e descarrega variáveis de ambiente automaticamente ao entrar e sair de diretórios. Essencial para trabalhar com múltiplos projetos com configurações distintas.

```bash
echo 'export AWS_PROFILE=staging' > .envrc
direnv allow                   # autoriza o .envrc do diretório
direnv deny                    # revoga a autorização
direnv reload                  # recarrega sem mudar de diretório
```

**Em produção:** isola configurações por projeto — perfil AWS, endpoint Kubernetes, variáveis de ambiente — sem precisar exportar manualmente ao trocar de contexto.

```bash
# Exemplo: .envrc num repositório de infraestrutura
# export AWS_PROFILE=production
# export AWS_DEFAULT_REGION=us-east-1
# export KUBECONFIG=~/.kube/prod-config
# export TF_WORKSPACE=production
```

#### zoxide

Substitui o `cd` com um sistema de frequência/recência — aprende os diretórios que você mais usa e navega para eles com poucos caracteres.

```bash
z meu-proj                 # vai para o diretório que contém "meu-proj"
z setup wsl                # múltiplos termos para refinar
zi                         # abre seletor interativo com fzf
z -                        # volta para o diretório anterior
```

#### xh

Cliente HTTP moderno para testar APIs direto do terminal — sintaxe mais simples que `curl`.

```bash
xh get httpbin.org/get
xh post httpbin.org/post nome=João idade:=30         # JSON automaticamente
xh -A bearer -a meu-token get api.exemplo.com/users  # bearer auth
xh -v get httpbin.org/get                            # verbose (headers + body)
xh --download get exemplo.com/arquivo.zip            # download de arquivo
```

#### htop

Monitor de processos interativo com visualização de CPU, memória e árvore de processos.

```bash
htop
```

| Tecla | O que faz |
|---|---|
| `F5` | Alterna entre lista e árvore de processos |
| `F6` | Ordena por coluna |
| `F9` | Mata o processo selecionado |
| `u` | Filtra por usuário |
| `q` | Fecha |

#### tree

Visualiza estrutura de diretórios em formato de árvore.

```bash
tree                           # árvore do diretório atual
tree -L 2                      # limita a 2 níveis
tree -I "node_modules|.git"    # ignora pastas
tree -a                        # inclui arquivos ocultos
tree -d                        # só diretórios
```

#### dig / nslookup

Ferramentas de consulta DNS — úteis para debug de networking no WSL e verificação de registros em produção.

```bash
dig google.com                 # consulta DNS completa
dig google.com +short          # só o IP
dig @8.8.8.8 google.com        # usa DNS específico
dig google.com MX              # registros de e-mail
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
