# Проверки

Требуются .NET SDK 8, PowerShell 7 и работающий PostgreSQL проекта в Docker.
Подготовьте локальные настройки по `docs/local-development.md`, затем:

```powershell
dotnet restore OnlineCinemaMvc.sln
dotnet tool restore
./scripts/Test-All.ps1
```

`Test-All` создаёт отдельную БД `codex_suite_<GUID>`, применяет миграции и
загружает демокаталог, места, расписание и роль администратора. Запускает свой
Production-сервер на свободном локальном порту с отдельными ключами cookies.
Регистрация, вход, блокировка, CSRF, доступ, админские изменения, покупки,
повторы/конкуренция, билеты, пустые страницы, безопасное отображение и ошибки
проверяются реальными HTTP-запросами и PostgreSQL, без in-memory замены.
Дополнительные временные БД проверяют миграцию с конфликтом и её откат.

В `finally` восстанавливается окружение процесса, останавливается собственный
сервер и удаляются только созданные скриптом БД с проверенными именами.
Рабочие пользователи и заказы не копируются и не меняются. Логи и резервные
копии остаются в игнорируемом `backups/`. Скрипты поддерживают Windows/Linux.
`-SkipBuild` допускается после успешной сборки.

Отдельные `Test-Authentication`, `Test-Sessions`, `Test-Admin`,
`Test-TicketPurchases` доступны с `-BaseUrl`; они требуют сайта и БД с
демокаталогом/расписанием. Для общей регрессии предпочитайте изолированный runner.

Для сайта в режиме demo передавайте `-DemoCalendar` в `Test-Sessions` и
`Test-TicketPurchases`: они используют постоянные даты вместо текущего дня.
`Test-All` отдельно проверяет production с будущими и прошедшими сеансами.
`Test-DemoCalendarPolicy` проверяет часы до, внутри и после демопериода;
для Release-сборки используйте `-Configuration Release`.

## GitHub Actions

Workflow запускается при push в master, pull request и вручную. На Ubuntu
восстанавливает SDK/EF, собирает с warnaserror, проверяет NuGet, поднимает
PostgreSQL и запускает Test-All. Рабочие секреты и backlog не нужны.
После интеграционных проверок отдельный job собирает Linux-образ из чистого
checkout и запускает `Test-ContainerMigrations`, `Test-ContainerDemo
-CheckScheduleRefresh` и `Test-ProductionMode`. Проверяются конкурентные миграции,
отказ инициализации, пустые volumes, локальные постеры, покупка и сохранение билета
после перезапуска, фоновое расписание, резервные копии и отдельная production-БД.
Каждый runner удаляет только собственный временный Compose-проект в `finally`.
Ключи, дампы и приватные журналы не публикуются как артефакты.

Внешние actions закреплены проверенными SHA официальных релизов; Dependabot
предлагает обновления NuGet и actions еженедельно. Политика GitHub:
https://docs.github.com/en/actions/reference/security/secure-use
