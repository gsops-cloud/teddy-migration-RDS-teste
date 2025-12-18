# Scripts de Automação

Este diretório contém scripts auxiliares para automação.

## 📄 migrate.sh

Script principal para execução de migrações via AWS SSM Session Manager.

### Funcionalidades

- Conecta à instância EC2/Bastion via SSM
- Executa comandos de migração remotamente
- Suporta múltiplas estratégias de acesso ao banco
- Logs detalhados de execução

### Personalização

Edite o script para adaptar à sua stack de tecnologia. Procure pela seção `MIGRATION_SCRIPT` e ajuste conforme necessário.
