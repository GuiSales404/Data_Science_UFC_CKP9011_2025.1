#!/bin/bash

# Caminho do arquivo CSV local
CSV_PATH="/home/guilherme-sales/Data_Science_UFC_CKP9011_2025.1/data/df_tratado.csv"
CSV_DEST="/tmp/df_tratado.csv"

# Criar rede Docker (se não existir)
if ! docker network ls | grep -q metabase_net; then
  echo "Criando rede Docker: metabase_net"
  docker network create metabase_net
else
  echo "Rede Docker 'metabase_net' já existe"
fi

# Criar volumes para persistência
docker volume create postgres_data >/dev/null 2>&1
docker volume create metabase_data >/dev/null 2>&1

# Subir PostgreSQL (atvd_4_ds)
if ! docker ps -a --format '{{.Names}}' | grep -q "^atvd_4_ds$"; then
  echo "Criando container PostgreSQL..."
  docker run --name atvd_4_ds \
    --network metabase_net \
    -e POSTGRES_USER=user \
    -e POSTGRES_PASSWORD=password \
    -e POSTGRES_DB=fake_telegram \
    -v postgres_data:/var/lib/postgresql/data \
    -p 5432:5432 \
    -d postgres:15
else
  echo "Container 'atvd_4_ds' já existe. Iniciando..."
  docker start atvd_4_ds
fi

# Subir Metabase
if ! docker ps -a --format '{{.Names}}' | grep -q "^metabase$"; then
  echo "Criando container Metabase..."
  docker run -d -p 3000:3000 \
    --name metabase \
    --network metabase_net \
    -e MB_DB_FILE=/metabase-data/metabase.db \
    -v metabase_data:/metabase-data \
    metabase/metabase
else
  echo "Container 'metabase' já existe. Iniciando..."
  docker start metabase
fi

# Copiar CSV para o container PostgreSQL
echo "Copiando CSV para o container PostgreSQL..."
docker cp "$CSV_PATH" atvd_4_ds:$CSV_DEST

# Criar a tabela e importar os dados via psql
echo "Importando dados para o PostgreSQL..."

sleep 6

docker exec -i atvd_4_ds psql -U user -d fake_telegram <<EOF
DROP TABLE IF EXISTS fake_telegram;
CREATE TABLE fake_telegram (
    date_message TEXT,
    id_member_anonymous TEXT,
    id_group_anonymous TEXT,
    media TEXT,
    media_type TEXT,
    media_url TEXT,
    has_media BOOLEAN,
    has_media_url BOOLEAN,
    trava_zap BOOLEAN,
    text_content_anonymous TEXT,
    dataset_info_id BIGINT,
    date_system TEXT,
    score_sentiment DOUBLE PRECISION,
    score_misinformation DOUBLE PRECISION,
    id_message BIGINT,
    message_type TEXT,
    messenger TEXT,
    media_name TEXT,
    media_md5 TEXT,
    word_count BIGINT
);
\copy fake_telegram FROM '$CSV_DEST' DELIMITER ',' CSV HEADER;
EOF

echo ""
echo "Ambiente pronto."
echo "Acesse o Metabase em: http://localhost:3000"
