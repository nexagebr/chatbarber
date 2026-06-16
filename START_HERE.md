# 🚀 Inicialização do Chatwoot Docker

## Status Atual

✅ PostgreSQL - Rodando na porta 5432
✅ Redis - Rodando na porta 6379  
✅ Mailhog - Rodando nas portas 1025 e 8025
🔄 Build das imagens Rails/Vite/Sidekiq - Em andamento

## Quando o Build Terminar (aprox. 10-15 min)

Execute os seguintes comandos na ordem:

### 1. Criar e popular o banco de dados

```powershell
cd "c:\Users\Ian Elber\Documents\chatbarber - Copia"
docker-compose run --rm rails bundle exec rails db:create
docker-compose run --rm rails bundle exec rails db:schema:load  
docker-compose run --rm rails bundle exec rails db:seed
```

### 2. Iniciar todos os serviços

```powershell
docker-compose up
```

Ou em background:
```powershell
docker-compose up -d
```

### 3. Acessar a aplicação

🌐 **Chatwoot**: http://localhost:3000  
📧 **Mailhog**: http://localhost:8025

## ⚡ Atalho Rápido

Depois que o build terminar, rode tudo de uma vez:

```powershell
cd "c:\Users\Ian Elber\Documents\chatbarber - Copia"
docker-compose run --rm rails bundle exec rails db:create db:schema:load db:seed
docker-compose up
```

## 🎯 Usando o Script Manager

O jeito mais fácil de gerenciar:

```powershell
.\docker-manager.ps1
```

Escolha:
- Opção 4: Criar banco de dados
- Opção 1: Iniciar serviços

## 🔍 Verificar se o Build Terminou

```powershell
docker images | Select-String "chatwoot"
```

Você deve ver 4 imagens:
- `chatwoot:development`
- `chatwoot-rails:development`
- `chatwoot-vite:development`  
- `chatwoot:development` (sidekiq usa a mesma base)

## 📝 Desenvolvimento

### Ver logs em tempo real

```powershell
# Todos os serviços
docker-compose logs -f

# Apenas Rails
docker-compose logs -f rails
```

### Executar comandos Rails

```powershell
# Console
docker-compose run --rm rails bundle exec rails console

# Migrations
docker-compose run --rm rails bundle exec rails db:migrate

# Testes
docker-compose run --rm rails bundle exec rspec
```

### Hot Reload

Todas as mudanças nos arquivos são refletidas automaticamente:
- ✅ Ruby files - auto-reload
- ✅ Vue/JS files - hot module replacement via Vite
- ✅ CSS/Tailwind - instant updates

## 🛑 Parar os Serviços

```powershell
# Parar (mantém volumes e dados)
docker-compose stop

# Parar e remover containers (mantém volumes)
docker-compose down

# Resetar tudo (remove volumes e dados)
docker-compose down -v
```

## ⚠️ Troubleshooting

### Porta 3000 já em uso

Edite [docker-compose.yaml](docker-compose.yaml) linha 36:

```yaml
ports:
  - "3001:3000"  # Muda para 3001
```

### Erro ao criar banco de dados

```powershell
# Recriar o PostgreSQL
docker-compose down
docker volume rm chatbarber-copia_postgres
docker-compose up -d postgres
# Aguarde 10 segundos
docker-compose run --rm rails bundle exec rails db:create db:schema:load
```

### Containers reiniciando continuamente

```powershell
# Ver o erro
docker-compose logs rails

# Rebuild se necessário
docker-compose build rails
```

## 📚 Documentação Completa

Ver [DOCKER_SETUP.md](DOCKER_SETUP.md) para mais detalhes.
