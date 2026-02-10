#!/bin/bash

# --- CONFIGURAÇÕES ---
DIRETORIO_ORIGEM="/caminho/para/backups"
DIRETORIO_DESTINO="/caminho/para/historico_compactado"
DIAS_LIMITE=7
EXTENSOES=("zip" "rsc" "tar")
DATA_HOJE=$(date +%Y-%m-%d)
ARQUIVO_FINAL="archive_old_backups_$DATA_HOJE.tar.gz"

# --- TELEGRAM CONFIG ---
TOKEN="SEU_TOKEN_AQUI"
CHAT_ID="SEU_CHAT_ID_AQUI"

# Criar diretório de destino se não existir
mkdir -p "$DIRETORIO_DESTINO"

# 1. Localizar os arquivos e salvar em uma lista temporária
LISTA_ARQUIVOS=$(mktemp)
for ext in "${EXTENSOES[@]}"; do
    find "$DIRETORIO_ORIGEM" -type f -iname "*.$ext" -mtime +$DIAS_LIMITE >> "$LISTA_ARQUIVOS"
done

total_arquivos=$(grep -c . "$LISTA_ARQUIVOS")

if [ "$total_arquivos" -gt 0 ]; then
    echo "Compactando $total_arquivos arquivos..."

    # 2. Compactar os arquivos da lista para o destino
    # O comando tar -T lê a lista de arquivos para incluir
    tar -czf "$DIRETORIO_DESTINO/$ARQUIVO_FINAL" -T "$LISTA_ARQUIVOS"

    if [ $? -eq 0 ]; then
        # 3. Se a compactação deu certo, apagar os originais
        while IFS= read -r arquivo; do
            rm -f "$arquivo"
        done < "$LISTA_ARQUIVOS"

        MENSAGEM="📦 *Rotatividade Concluída*%0A%0A*$total_arquivos* arquivos foram compactados em \`$ARQUIVO_FINAL\` e movidos para o histórico. Originais removidos."
    else
        MENSAGEM="⚠️ *Erro na Rotatividade*%0A%0AFalha ao tentar compactar os arquivos de backup."
    fi
else
    MENSAGEM="ℹ️ *Rotatividade*: Nenhum arquivo antigo encontrado para processar."
    echo "Nada para fazer."
fi

# --- ENVIO PARA O TELEGRAM ---
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
    -d "chat_id=$CHAT_ID" \
    -d "text=$MENSAGEM" \
    -d "parse_mode=Markdown" > /dev/null

# Limpar arquivo temporário
rm -f "$LISTA_ARQUIVOS"
