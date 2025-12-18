# teddy-migration-RDS

Pipeline automatizada para execução de migrações de banco de dados em sub-rede privada AWS usando GitHub Actions.

## 📋 Visão Geral

Este projeto implementa uma solução completa para executar migrações de banco de dados de forma automatizada antes do deploy, utilizando GitHub Actions e AWS Systems Manager Session Manager para acessar bancos de dados em sub-redes privadas.

## 🏗️ Arquitetura

A solução utiliza:
- **GitHub Actions** para orquestração das pipelines
- **AWS Systems Manager Session Manager** para acesso seguro ao banco privado
- **Detecção automática de mudanças** para executar apenas quando necessário
- **Separação de responsabilidades** entre migração e deploy

## 📁 Estrutura do Projeto

```
.
├── .github/
│   └── workflows/
│       ├── database-migration.yml  # Pipeline de migrações
│       └── deploy.yml              # Pipeline de deploy
├── scripts/
│   └── migrate.sh                  # Script de execução de migrações
├── migrations/                     # Diretório para arquivos de migração
└── README.md
```

## 🚀 Funcionalidades

### Pipeline de Migração (`database-migration.yml`)

- ✅ Executa **apenas quando há mudanças** em arquivos de migração
- ✅ Suporta execução manual via `workflow_dispatch`
- ✅ Usa AWS SSM Session Manager para acesso seguro
- ✅ Suporta múltiplos ambientes (staging, production)
- ✅ Notificações de sucesso/falha

### Pipeline de Deploy (`deploy.yml`)

- ✅ Verifica se há migrações pendentes antes do deploy
- ✅ Executa apenas quando não há migrações pendentes
- ✅ Previne deploy sem migrações aplicadas

## ⚙️ Configuração

### 1. Secrets do GitHub

Configure os seguintes secrets no GitHub (Settings → Secrets and variables → Actions):

```
AWS_ACCESS_KEY_ID          # Credenciais AWS com permissões SSM
AWS_SECRET_ACCESS_KEY      # Credenciais AWS
SSM_INSTANCE_ID            # ID da instância EC2/Bastion com SSM habilitado
DB_HOST                    # Host do banco de dados
DB_PORT                    # Porta do banco (padrão: 5432 para PostgreSQL, 3306 para MySQL)
DB_NAME                    # Nome do banco de dados
DB_USER                    # Usuário do banco de dados
```

### 2. Configuração AWS

#### Instância EC2/Bastion

A instância usada para acessar o banco deve ter:

1. **AWS Systems Manager Agent (SSM Agent)** instalado e rodando
2. **IAM Role** com as seguintes políticas:
   - `AmazonSSMManagedInstanceCore`
   - Permissões para acessar o RDS (se necessário)
3. **Acesso de rede** ao banco de dados RDS na sub-rede privada
4. **Ferramentas de banco de dados** instaladas (psql, mysql, etc.)

#### Configuração IAM para GitHub Actions

Crie um usuário IAM ou role com as seguintes permissões:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand",
        "ssm:GetCommandInvocation",
        "ssm:ListCommandInvocations"
      ],
      "Resource": [
        "arn:aws:ssm:*:*:document/AWS-RunShellScript",
        "arn:aws:ec2:*:*:instance/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:DescribeInstanceInformation"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. Variáveis de Ambiente

Ajuste a região AWS no arquivo `.github/workflows/database-migration.yml`:

```yaml
env:
  AWS_REGION: us-east-1  # Altere para sua região
```

## 📝 Como Usar

### Executar Migrações Automaticamente

1. Adicione arquivos de migração no diretório `migrations/`
2. Faça commit e push para `main` ou `develop`
3. A pipeline será executada automaticamente se houver mudanças em `migrations/`

### Executar Migrações Manualmente

1. Vá para **Actions** no GitHub
2. Selecione **Database Migration**
3. Clique em **Run workflow**
4. Escolha o ambiente (staging/production)
5. Clique em **Run workflow**

### Estrutura de Migrações

Coloque seus arquivos de migração no diretório `migrations/`. Exemplos:

- **SQL puro**: `migrations/001_create_users_table.sql`
- **Scripts Python**: `migrations/002_add_indexes.py`
- **Scripts Shell**: `migrations/003_update_schema.sh`

### Personalizar Script de Migração

Edite `scripts/migrate.sh` para adaptar à sua stack:

#### Para Django/Python:
```bash
source /path/to/venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
```

#### Para Node.js/Sequelize:
```bash
npm install
npm run migrate
```

#### Para Flyway (Java):
```bash
flyway migrate
```

#### Para SQL direto:
```bash
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f migrations/001_initial.sql
```

## 🔒 Segurança

- ✅ Credenciais armazenadas como GitHub Secrets
- ✅ Acesso via AWS SSM Session Manager (sem expor portas)
- ✅ Sem necessidade de chaves SSH
- ✅ Logs de auditoria via AWS CloudTrail
- ✅ Suporte a ambientes separados (staging/production)

## 🔄 Fluxo de Trabalho

```
┌─────────────────┐
│  Push para repo │
└────────┬────────┘
         │
         ├─ Mudanças em migrations/?
         │  ├─ SIM → Executa database-migration.yml
         │  └─ NÃO → Executa deploy.yml
         │
         ├─ database-migration.yml
         │  ├─ Detecta mudanças
         │  ├─ Conecta via SSM
         │  └─ Executa migrações
         │
         └─ deploy.yml
            ├─ Verifica migrações pendentes
            └─ Executa deploy
```

## 🐛 Troubleshooting

### Erro: "SSM_INSTANCE_ID não está definido"
- Verifique se o secret `SSM_INSTANCE_ID` está configurado no GitHub

### Erro: "Command failed with status: Failed"
- Verifique os logs do comando SSM no AWS Console
- Confirme que a instância tem acesso ao banco de dados
- Verifique se as ferramentas de banco estão instaladas na instância

### Migrações não executam automaticamente
- Verifique se os arquivos estão no diretório `migrations/`
- Confirme que o caminho no workflow está correto
- Use `workflow_dispatch` para execução manual

### Instância SSM não encontrada
- Verifique se o SSM Agent está rodando: `sudo systemctl status amazon-ssm-agent`
- Confirme que a instância tem a IAM Role correta
- Verifique se a instância aparece no AWS Systems Manager Console