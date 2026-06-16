# Script para gerenciar o Chatwoot no Docker

Write-Host "=== Chatwoot Docker Manager ===" -ForegroundColor Cyan
Write-Host ""

$action = Read-Host "Escolha uma ação:
1 - Iniciar todos os serviços
2 - Parar todos os serviços  
3 - Ver logs
4 - Criar banco de dados
5 - Console do Rails
6 - Rodar migrations
7 - Reinstalar dependências
8 - Status dos containers
9 - Rebuild completo
0 - Sair

Digite o número"

switch ($action) {
    "1" {
        Write-Host "`nIniciando serviços..." -ForegroundColor Green
        docker-compose up -d
        Write-Host "`nServiços iniciados!" -ForegroundColor Green
        Write-Host "Aplicação: http://localhost:3000" -ForegroundColor Yellow
        Write-Host "Mailhog: http://localhost:8025" -ForegroundColor Yellow
    }
    
    "2" {
        Write-Host "`nParando serviços..." -ForegroundColor Yellow
        docker-compose stop
        Write-Host "`nServiços parados!" -ForegroundColor Green
    }
    
    "3" {
        $service = Read-Host "`nQual serviço? (rails/sidekiq/vite/postgres/redis/todos)"
        if ($service -eq "todos") {
            docker-compose logs -f
        } else {
            docker-compose logs -f $service
        }
    }
    
    "4" {
        Write-Host "`nCriando banco de dados..." -ForegroundColor Green
        docker-compose run --rm rails bundle exec rails db:create
        docker-compose run --rm rails bundle exec rails db:schema:load
        docker-compose run --rm rails bundle exec rails db:seed
        Write-Host "`nBanco de dados criado!" -ForegroundColor Green
    }
    
    "5" {
        Write-Host "`nAbrindo console do Rails..." -ForegroundColor Green
        docker-compose run --rm rails bundle exec rails console
    }
    
    "6" {
        Write-Host "`nRodando migrations..." -ForegroundColor Green
        docker-compose run --rm rails bundle exec rails db:migrate
        Write-Host "`nMigrations concluídas!" -ForegroundColor Green
    }
    
    "7" {
        Write-Host "`nReinstalando dependências..." -ForegroundColor Yellow
        docker-compose run --rm rails bundle install
        docker-compose run --rm vite pnpm install
        Write-Host "`nDependências reinstaladas!" -ForegroundColor Green
    }
    
    "8" {
        Write-Host "`nStatus dos containers:" -ForegroundColor Cyan
        docker-compose ps
    }
    
    "9" {
        Write-Host "`nREBUILD COMPLETO - Isso vai demorar!" -ForegroundColor Red
        $confirm = Read-Host "Tem certeza? (s/n)"
        if ($confirm -eq "s") {
            Write-Host "`nParando containers..." -ForegroundColor Yellow
            docker-compose down
            Write-Host "`nLimpando cache..." -ForegroundColor Yellow
            docker builder prune -f
            Write-Host "`nConstruindo imagens..." -ForegroundColor Yellow
            docker-compose build --no-cache
            Write-Host "`nReconstrução completa!" -ForegroundColor Green
        }
    }
    
    "0" {
        Write-Host "`nAté logo!" -ForegroundColor Cyan
        exit
    }
    
    default {
        Write-Host "`nOpção inválida!" -ForegroundColor Red
    }
}

Write-Host "`nPressione Enter para continuar..."
Read-Host
