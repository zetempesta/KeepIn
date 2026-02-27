# Project Structure

```text
backend/
  app/
    config.py
    database.py
    main.py
    schemas.py
  requirements.txt

lib/
  app.dart
  main.dart
  core/
    config/
      app_config.dart
    di/
      providers.dart
    theme/
      app_colors.dart
      app_theme.dart
  data/
    repositories/
      notes_repository_impl.dart
    services/
      database_service.dart
  domain/
    entities/
      note.dart
    repositories/
      notes_repository.dart
  presentation/
    controllers/
      notes_controller.dart
    pages/
      notes_board_page.dart
    widgets/
      note_card.dart
```

## Guidelines

- `backend`: API HTTP com FastAPI para isolar o acesso ao PostgreSQL e expor o CRUD.
- `domain`: contratos e entidades imutáveis.
- `data`: cliente HTTP, cache local e implementação de repositórios.
- `presentation`: widgets, páginas e providers de UI.
- `core`: tema, DI, utilitários e configuração transversal.
