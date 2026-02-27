# KeepIn

Base inicial de um aplicativo Flutter multiplataforma inspirado no Google Keep, com backend FastAPI para acesso ao PostgreSQL.

## Stack

- Flutter Stable
- Riverpod para gerenciamento de estado com foco em testabilidade
- FastAPI + PostgreSQL para backend remoto
- `sqflite` para cache/local mirror opcional
- Material Design 3 adaptado ao design fornecido

## Rodando o backend

1. `cd backend`
2. `python3 -m venv .venv`
3. `source .venv/bin/activate`
4. `pip install -r requirements.txt`
5. Copiar `backend/.env.example` para `backend/.env` e ajustar as credenciais.
6. `uvicorn app.main:app --reload --host 127.0.0.1 --port 8000`

## Rodando o Flutter

1. Executar `flutter pub get`.
2. Garantir que o backend esteja ativo em `http://127.0.0.1:8000`.
3. Executar `flutter run -d chrome` ou no target desejado.
