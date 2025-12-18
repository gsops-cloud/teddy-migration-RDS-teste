# Migrações de Banco de Dados

Este diretório contém os arquivos de migração do banco de dados.

## 📝 Formato

Os arquivos de migração podem estar em qualquer formato suportado pela sua stack:

- **SQL**: Arquivos `.sql` para execução direta
- **Python**: Scripts `.py` para Django, Alembic, etc.
- **JavaScript/TypeScript**: Scripts para Sequelize, TypeORM, etc.
- **Shell**: Scripts `.sh` para comandos customizados

## 📋 Convenções de Nomenclatura

Recomenda-se usar numeração sequencial para garantir ordem de execução:

```
001_initial_schema.sql
002_add_users_table.sql
003_create_indexes.sql
004_add_foreign_keys.sql
```

## ⚠️ Importante

- As migrações são executadas **automaticamente** quando há mudanças neste diretório
- Certifique-se de que as migrações são **idempotentes** quando possível
- Teste as migrações em ambiente de staging antes de produção
- Faça backup do banco antes de executar migrações em produção

## 🔄 Ordem de Execução

O script `migrate.sh` executa os arquivos na ordem alfabética. Use numeração para controlar a ordem.
