# Chatwoot - Setup Docker para Desenvolvimento Local

## ⚡ Início Rápido

Use o script gerenciador para facilitar:

```powershell
.\docker-manager.ps1
```

Ou siga os passos manuais abaixo.

## Status Atual

O Docker está construindo as imagens necessárias. Este processo pode levar de 15-30 minutos na primeira vez.

## Após o Build Completar

### 1. Verificar se as imagens foram criadas

```powershell
docker images | Select-String "chatwoot"
```

Você deve ver:
- `chatwoot:development`
- `chatwoot-rails:development`
- `chatwoot-vite:development`

### 2. Construir as imagens restantes (se necessário)

```powershell
cd "c:\Users\Ian Elber\Documents\chatbarber - Copia"
docker-compose build rails vite sidekiq
```

### 3. Criar o banco de dados

```powershell
docker-compose run --rm rails bundle exec rails db:create db:schema:load db:seed
```

### 4. Iniciar todos os serviços

```powershell
docker-compose up
```

Ou para rodar em background:

```powershell
docker-compose up -d
```

### 5. Acessar a aplicação

- **Aplicação principal**: http://localhost:3000
- **Mailhog (emails de desenvolvimento)**: http://localhost:8025
- **Vite dev server**: http://localhost:3036

### 6. Ver logs

```powershell
# Todos os serviços
docker-compose logs -f

# Apenas o Rails
docker-compose logs -f rails

# Apenas o Sidekiq (jobs em background)
docker-compose logs -f sidekiq
```

### 7. Parar os serviços

```powershell
docker-compose stop
```

Ou para parar e remover os containers:

```powershell
docker-compose down
```

## Modificando Arquivos

Os volumes estão configurados para mapear sua pasta local (`./`) para `/app` dentro do container.

Isso significa que:
- ✅ Mudanças em arquivos Ruby (`.rb`) serão refletidas automaticamente
- ✅ Mudanças em arquivos Vue/JS serão hot-reloaded pelo Vite
- ✅ Mudanças em arquivos CSS/Tailwind serão atualizadas automaticamente

## Comandos Úteis

### Executar comandos Rails

```powershell
# Console do Rails
docker-compose run --rm rails bundle exec rails console

# Criar uma migration
docker-compose run --rm rails bundle exec rails g migration NomeDaMigration

# Rodar migrations
docker-compose run --rm rails bundle exec rails db:migrate

# Rodar testes
docker-compose run --rm rails bundle exec rspec
```

### Executar comandos PNPM

```powershell
# Instalar dependências
docker-compose run --rm vite pnpm install

# Adicionar um pacote
docker-compose run --rm vite pnpm add nome-do-pacote

# Rodar lint
docker-compose run --rm vite pnpm eslint
```

### Resetar o banco de dados

```powershell
docker-compose run --rm rails bundle exec rails db:reset
```

## Solução de Problemas

### Build falhou ou foi interrompido

Limpe o cache e tente novamente:

```powershell
docker builder prune -f
docker-compose build --no-cache base
docker-compose build
```

### Problemas com permissões de volume

Se você tiver problemas com permissões, pode ser necessário recriar os volumes:

```powershell
docker-compose down -v
docker-compose up
```

### Container não inicia ou fica reiniciando

Verifique os logs:

```powershell
docker-compose logs rails
```

### Porta já em uso

Se a porta 3000 já estiver em uso, você pode mudá-la no `docker-compose.yaml`:

```yaml
ports:
  - "3001:3000"  # Muda a porta externa para 3001
```

## Estrutura dos Volumes

O projeto usa volumes nomeados para melhor performance:

- `node_modules`: Dependências Node.js
- `packs`: Assets compilados
- `cache`: Cache do Rails
- `bundle`: Gems Ruby instaladas
- `postgres`: Dados do PostgreSQL
- `redis`: Dados do Redis

Estes volumes persistem mesmo quando você para os containers, garantindo que não seja necessário reinstalar dependências toda vez.

## Próximos Passos

1. Aguarde o build completar
2. Execute o comando de criação do banco de dados (#3)
3. Inicie os serviços (#4)
4. Acesse http://localhost:3000

Qualquer alteração nos arquivos do projeto será refletida automaticamente nos containers em execução!
