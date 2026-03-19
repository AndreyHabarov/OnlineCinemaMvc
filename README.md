# Online Cinema

ASP.NET Core MVC application for an online cinema website with movie catalog, sessions, promotions, news, ticket ordering, user accounts, and an admin area for content management.

The solution is split into several parts:

- `OnlineCinema.Mvc` - ASP.NET Core MVC application, Razor views, controllers, admin area, static assets
- `OnlineCinema.Domain` - entities, `AppDbContext`, ASP.NET Core Identity, EF Core migrations
- `OnlineCinema.Application` - placeholder application layer project

## Tech Stack

- .NET 8
- ASP.NET Core MVC
- Razor Views
- Entity Framework Core 8
- PostgreSQL
- ASP.NET Core Identity
- AutoMapper
- JavaScript
- Bootstrap

## Database Configuration

```json
"ConnectionStrings": {
  "Default": "User ID=postgres;Password=postgres;Host=localhost;Port=5432;Database=cinemadb;Pooling=true;"
}
```

The project uses PostgreSQL via `Npgsql`. A Docker Compose configuration is also included.

```yaml
services:
  cinema.pgsql:
    image: postgres:12.4-alpine
    ports:
      - "5433:5432"
    environment:
      - POSTGRES_PASSWORD=123qwe
      - POSTGRES_DB=cinemadb
```

If you use Docker, update the application connection string to match the exposed container port and password.

Example:

```json
"ConnectionStrings": {
  "Default": "User ID=postgres;Password=123qwe;Host=localhost;Port=5433;Database=cinemadb;Pooling=true;"
}
```

## How To Run

1. Clone the repository:

```powershell
git clone <repo-url>
cd OnlineCinema
```

2. Restore dependencies:

```powershell
dotnet restore .\OnlineCinemaMvc.sln
```

3. Apply EF Core migrations:

```powershell
dotnet ef database update --project .\OnlineCinema.Domain\OnlineCinema.Domain.csproj --startup-project .\OnlineCinema.Mvc\OnlineCinema.Mvc.csproj
```

4. Run the MVC application:

```powershell
dotnet run --project .\OnlineCinema.Mvc\OnlineCinema.Mvc.csproj
```
