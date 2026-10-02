# Kampive Infra

API Java 21/Spring Boot 4.1.1 e PostgreSQL 18.6 em Docker Compose.
Clone kampive-api e kampive-infra lado a lado. Não exige Java, Maven ou PostgreSQL no host.

## Primeira execução

Dentro de kampive-infra:

```sh
cp .env.example .env
```

Preencha POSTGRES_ADMIN_PASSWORD e DB_APP_PASSWORD com senhas fortes diferentes.
.env é ignorado pelo Git. Não compartilhe a saída de docker compose config; use
--quiet para validar sem mostrar segredos.

```sh
docker compose config --quiet
docker compose up -d --wait postgres
docker compose exec postgres psql -U postgres -d kampive
```

A imagem cria apenas o banco vazio kampive. Dentro do psql, provisione manualmente:

```sql
CREATE ROLE kampive_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOREPLICATION NOBYPASSRLS;

-- Digite a mesma senha definida em DB_APP_PASSWORD.
\password kampive_app

REVOKE ALL ON DATABASE kampive FROM PUBLIC;
GRANT CONNECT ON DATABASE kampive TO kampive_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
CREATE SCHEMA kampive AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA kampive FROM PUBLIC;
GRANT USAGE ON SCHEMA kampive TO kampive_app;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA kampive
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO kampive_app;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA kampive
    GRANT USAGE, SELECT ON SEQUENCES TO kampive_app;
\q
```

Faça isso uma única vez por volume novo. Não há scripts de inicialização montados
nem migrations. Depois:

```sh
docker compose up -d --build api
curl --fail http://localhost:8080/actuator/health
```

Resposta com status `UP` (pode incluir os grupos de saúde). Todas as demais rotas são bloqueadas.
O Dockerfile só gera a imagem final após os testes passarem.

## Schema de negócio

O arquivo `sql/schema.sql` cria 30 tabelas e 3 views com nomes em inglês,
PKs internas `id`, UUIDs únicos e chaves estrangeiras por UUID. As fotos possuem
posições únicas de 1 a 9 por camping e de 1 a 3 por avaliação. Contagens e médias
são calculadas em views. Nenhum dado inicial é inserido.

Após provisionar o usuário e o schema, aplique **uma vez por banco novo**:

```sh
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d kampive < sql/schema.sql
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d kampive < sql/verify-schema.sql
```

A criação é transacional e falha se as tabelas já existirem. O teste usa o papel
restrito da API e desfaz suas linhas com ROLLBACK; sequências podem avançar.
O SQL é aplicado manualmente como administrador, no banco existente, sem
repetir CREATE DATABASE ou CREATE SCHEMA. A API não cria tabelas e não recebe DDL.
Privilégios padrão valem apenas para objetos futuros criados pela role postgres.
Se outra role criar objetos, configure ALTER DEFAULT PRIVILEGES para ela.
Para objetos já existentes:

```sql
GRANT SELECT, INSERT, UPDATE, DELETE
    ON ALL TABLES IN SCHEMA kampive TO kampive_app;
GRANT USAGE, SELECT
    ON ALL SEQUENCES IN SCHEMA kampive TO kampive_app;
```

Ainda não há entidades JPA: validate não valida o modelo de negócio até adicionarmos
os mapeamentos. Nunca ativar create/update ou inicialização SQL automática.

## Uso diário

```sh
docker compose up -d
docker compose logs -f api
docker compose logs -f postgres
docker compose ps
docker compose up -d --build api
docker compose stop
docker compose down
```

down mantém o volume. **Não use down -v ou volume prune: isso apaga dados.**
Mudar senhas no .env não atualiza roles existentes: faça a rotação no psql e recrie a API.

API: http://localhost:8080. DBeaver: localhost:5432, banco kampive, usuário kampive_app
ou postgres apenas para administração. O simulador iOS do Mac acessa localhost.
Dispositivos físicos exigirão configuração explícita de exposição na LAN.

## Validação

```sh
docker build --target build --progress=plain -t kampive-api-tests:local ../kampive-api
docker compose config --quiet
curl --fail http://localhost:8080/actuator/health
curl -i http://localhost:8080/api/campsites
docker compose exec postgres psql -U postgres -d kampive
```

```sql
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolbypassrls
FROM pg_roles WHERE rolname = 'kampive_app';
SELECT has_database_privilege('kampive_app', 'kampive', 'CREATE'),
       has_database_privilege('kampive_app', 'kampive', 'TEMP'),
       has_schema_privilege('kampive_app', 'kampive', 'CREATE'),
       has_schema_privilege('kampive_app', 'public', 'CREATE');
SELECT count(*) FROM information_schema.tables WHERE table_schema = 'kampive';
```

Os privilégios de criação são false. Após aplicar o script, há 30 tabelas e
3 views (33 entradas em information_schema.tables). Para testar persistência,
registre os OIDs do banco e de uma tabela, recrie os containers com
`docker compose up -d --force-recreate --no-build` e confira os OIDs e dados novamente. Não utilize volumes de produção.

Imagens oficiais fixadas por digest, com suporte à arquitetura do host (Apple Silicon
incluído). API sem privilégios e portas em 127.0.0.1. Revisar digests e executar testes
ao atualizar imagens. Sem TLS ou implantação de produção nesta etapa.
