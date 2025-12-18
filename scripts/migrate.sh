#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Iniciando processo de migração de banco de dados...${NC}"

if [ -z "$SSM_INSTANCE_ID" ]; then
    echo -e "${RED}❌ Erro: SSM_INSTANCE_ID não está definido${NC}"
    exit 1
fi

if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    echo -e "${RED}❌ Erro: Variáveis de banco de dados não estão definidas${NC}"
    exit 1
fi

run_via_ssm() {
    local command="$1"
    local description="$2"
    
    echo -e "${YELLOW}📋 $description${NC}"
    
    aws ssm send-command \
        --instance-ids "$SSM_INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[$command]" \
        --output text \
        --query "Command.CommandId" > /tmp/command-id.txt
    
    COMMAND_ID=$(cat /tmp/command-id.txt)
    echo -e "${YELLOW}⏳ Aguardando execução do comando (ID: $COMMAND_ID)...${NC}"
    
    while true; do
        STATUS=$(aws ssm get-command-invocation \
            --command-id "$COMMAND_ID" \
            --instance-id "$SSM_INSTANCE_ID" \
            --query "Status" \
            --output text)
        
        if [ "$STATUS" = "Success" ]; then
            echo -e "${GREEN}✅ Comando executado com sucesso${NC}"
            aws ssm get-command-invocation \
                --command-id "$COMMAND_ID" \
                --instance-id "$SSM_INSTANCE_ID" \
                --query "StandardOutputContent" \
                --output text
            return 0
        elif [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Cancelled" ] || [ "$STATUS" = "TimedOut" ]; then
            echo -e "${RED}❌ Comando falhou com status: $STATUS${NC}"
            aws ssm get-command-invocation \
                --command-id "$COMMAND_ID" \
                --instance-id "$SSM_INSTANCE_ID" \
                --query "StandardErrorContent" \
                --output text
            return 1
        fi
        
        sleep 2
    done
}

copy_file_via_ssm() {
    local local_file="$1"
    local remote_path="$2"
    
    local file_content=$(cat "$local_file" | sed "s/'/'\\\\''/g")
    
    local command="cat > '$remote_path' << 'FILE_EOF'
$file_content
FILE_EOF"
    
    run_via_ssm "$command" "Copiando $(basename $local_file) para instância remota"
}

run_migration_with_port_forward() {
    echo -e "${YELLOW}🔌 Preparando migrações na instância remota...${NC}"
    
    run_via_ssm "mkdir -p /tmp/migrations" "Criando diretório de migrações remoto"
    
    echo -e "${YELLOW}📦 Copiando arquivos de migração...${NC}"
    for migration_file in migrations/*; do
        if [ -f "$migration_file" ] && [ "$(basename $migration_file)" != ".gitkeep" ] && [ "$(basename $migration_file)" != "README.md" ]; then
            copy_file_via_ssm "$migration_file" "/tmp/migrations/$(basename $migration_file)"
        fi
    done
    
    MIGRATION_SCRIPT=$(cat <<'MIGRATION_EOF'
#!/bin/bash
set -e

echo "🚀 Iniciando execução de migrações..."

export DB_HOST="${DB_HOST}"
export DB_PORT="${DB_PORT:-5432}"
export DB_NAME="${DB_NAME}"
export DB_USER="${DB_USER}"

if [ -z "$DB_TYPE" ]; then
    if [ "$DB_PORT" = "5432" ] || [ -z "$DB_PORT" ]; then
        DB_TYPE="postgresql"
    elif [ "$DB_PORT" = "3306" ]; then
        DB_TYPE="mysql"
    else
        DB_TYPE="postgresql"
    fi
fi

echo "📊 Tipo de banco detectado: $DB_TYPE"
echo "🔗 Conectando em: $DB_HOST:$DB_PORT/$DB_NAME"

if [ "$DB_TYPE" = "postgresql" ]; then
    for sql_file in /tmp/migrations/*.sql; do
        if [ -f "$sql_file" ]; then
            echo "📝 Executando: $(basename $sql_file)"
            PGPASSWORD="${DB_PASSWORD}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$sql_file" || exit 1
        fi
    done
elif [ "$DB_TYPE" = "mysql" ]; then
    for sql_file in /tmp/migrations/*.sql; do
        if [ -f "$sql_file" ]; then
            echo "📝 Executando: $(basename $sql_file)"
            mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"${DB_PASSWORD}" "$DB_NAME" < "$sql_file" || exit 1
        fi
    done
fi

for py_file in /tmp/migrations/*.py; do
    if [ -f "$py_file" ]; then
        echo "🐍 Executando: $(basename $py_file)"
        python3 "$py_file" || exit 1
    fi
done

for sh_file in /tmp/migrations/*.sh; do
    if [ -f "$sh_file" ]; then
        echo "📜 Executando: $(basename $sh_file)"
        chmod +x "$sh_file"
        bash "$sh_file" || exit 1
    fi
done

echo "✅ Todas as migrações foram executadas com sucesso!"
MIGRATION_EOF
)
    
    echo "$MIGRATION_SCRIPT" > /tmp/remote_migrate_script.sh
    copy_file_via_ssm "/tmp/remote_migrate_script.sh" "/tmp/execute_migrations.sh"
    rm -f /tmp/remote_migrate_script.sh
    
    run_via_ssm "chmod +x /tmp/execute_migrations.sh" "Tornando script executável"
    
    local env_vars="DB_HOST='$DB_HOST' DB_PORT='$DB_PORT' DB_NAME='$DB_NAME' DB_USER='$DB_USER'"
    if [ -n "$DB_PASSWORD" ]; then
        env_vars="$env_vars DB_PASSWORD='$DB_PASSWORD'"
    fi
    
    run_via_ssm "cd /tmp && $env_vars bash execute_migrations.sh" "Executando migrações no banco de dados"
    
    run_via_ssm "rm -rf /tmp/migrations /tmp/execute_migrations.sh" "Limpando arquivos temporários"
}

echo -e "${GREEN}🎯 Executando migrações via instância SSM...${NC}"

if [ ! -d "migrations" ] || [ -z "$(ls -A migrations 2>/dev/null)" ]; then
    echo -e "${YELLOW}⚠️  Nenhum arquivo de migração encontrado${NC}"
    exit 0
fi

run_migration_with_port_forward

echo -e "${GREEN}✨ Processo de migração concluído!${NC}"