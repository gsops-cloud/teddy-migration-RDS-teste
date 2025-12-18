# Guia de Configuração

Este guia detalha como configurar a pipeline de migrações de banco de dados.

## 📋 Pré-requisitos

1. **Repositório GitHub** com Actions habilitado
2. **Conta AWS** com permissões adequadas
3. **Instância EC2** ou **Bastion Host** na mesma VPC do RDS
4. **RDS** configurado em sub-rede privada

## 🔧 Passo a Passo

### 1. Configurar Instância EC2/Bastion

#### 1.1. Criar ou usar instância existente

A instância deve estar:
- Na mesma VPC do RDS (ou com conectividade de rede)
- Com acesso de segurança ao RDS (Security Group)
- Com SSM Agent instalado e rodando

#### 1.2. Verificar SSM Agent

```bash
# Conectar na instância
ssh -i sua-chave.pem ec2-user@seu-bastion-ip

# Verificar status do SSM Agent
sudo systemctl status amazon-ssm-agent

# Se não estiver rodando, instalar:
sudo yum install -y amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
```

#### 1.3. Configurar IAM Role para a Instância

1. Vá para **IAM Console** → **Roles**
2. Crie uma nova role ou edite a existente
3. Adicione a política: `AmazonSSMManagedInstanceCore`
4. Adicione permissões para acessar o RDS (se necessário)
5. Anexe a role à instância EC2

### 2. Configurar Secrets no GitHub

1. Vá para seu repositório no GitHub
2. **Settings** → **Secrets and variables** → **Actions**
3. Clique em **New repository secret**
4. Adicione os seguintes secrets:

| Secret | Descrição | Exemplo |
|--------|-----------|---------|
| `AWS_ACCESS_KEY_ID` | Access Key ID do usuário IAM | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | Secret Access Key do usuário IAM | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `SSM_INSTANCE_ID` | ID da instância EC2 (i-xxxxx) | `i-0123456789abcdef0` |
| `DB_HOST` | Endpoint do RDS | `mydb.xxxxx.us-east-1.rds.amazonaws.com` |
| `DB_PORT` | Porta do banco | `5432` (PostgreSQL) ou `3306` (MySQL) |
| `DB_NAME` | Nome do banco de dados | `mydatabase` |
| `DB_USER` | Usuário do banco | `admin` |
| `DB_PASSWORD` | Senha do banco (opcional) | `sua-senha-segura` |

### 3. Configurar IAM User para GitHub Actions

1. Vá para **IAM Console** → **Users**
2. Crie um novo usuário ou use existente
3. Anexe a seguinte política (ou crie uma customizada):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand",
        "ssm:GetCommandInvocation",
        "ssm:ListCommandInvocations",
        "ssm:DescribeInstanceInformation"
      ],
      "Resource": [
        "arn:aws:ssm:*:*:document/AWS-RunShellScript",
        "arn:aws:ec2:*:*:instance/*"
      ]
    }
  ]
}
```

4. Crie Access Keys para o usuário
5. Adicione as keys como secrets no GitHub

### 4. Configurar Security Groups

#### 4.1. Security Group do RDS

Permitir tráfego da instância bastion:
- **Type**: PostgreSQL (ou MySQL, conforme seu banco)
- **Port**: 5432 (ou 3306 para MySQL)
- **Source**: Security Group da instância bastion

#### 4.2. Security Group da Instância Bastion

Permitir tráfego de saída para o RDS:
- **Type**: All traffic
- **Destination**: Security Group do RDS

### 5. Testar Configuração

#### 5.1. Testar SSM Connection

```bash
# No seu computador local (com AWS CLI configurado)
aws ssm start-session --target i-0123456789abcdef0
```

Se conseguir conectar, o SSM está funcionando corretamente.

#### 5.2. Testar Acesso ao Banco

```bash
# Via SSM Session
aws ssm send-command \
  --instance-ids i-0123456789abcdef0 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["psql -h seu-rds-endpoint -U seu-usuario -d seu-banco -c \"SELECT version();\""]'
```

### 6. Criar Primeira Migração

1. Crie um arquivo em `migrations/`:

```sql
-- migrations/001_initial.sql
CREATE TABLE IF NOT EXISTS schema_version (
    version VARCHAR(255) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

2. Faça commit e push:

```bash
git add migrations/001_initial.sql
git commit -m "Add initial migration"
git push origin main
```

3. A pipeline será executada automaticamente!

### 7. Verificar Execução

1. Vá para **Actions** no GitHub
2. Veja a execução da pipeline **Database Migration**
3. Verifique os logs para confirmar sucesso

## 🔍 Troubleshooting

### Erro: "Instance is not in ready state"

- Verifique se o SSM Agent está rodando na instância
- Confirme que a instância tem a IAM Role correta
- Aguarde alguns minutos após criar/atualizar a role

### Erro: "Access Denied"

- Verifique as permissões IAM do usuário GitHub Actions
- Confirme que a instância tem permissão para acessar o RDS
- Verifique os Security Groups

### Erro: "Connection timeout"

- Verifique se o RDS está acessível da instância bastion
- Confirme os Security Groups
- Teste a conexão manualmente via SSM

### Migrações não executam

- Verifique se os arquivos estão em `migrations/`
- Confirme que o caminho no workflow está correto
- Veja os logs da pipeline para detalhes

## 📚 Próximos Passos

- Configure ambientes separados (staging/production)
- Adicione notificações (Slack, email, etc.)
- Implemente rollback de migrações
- Adicione testes de migração
