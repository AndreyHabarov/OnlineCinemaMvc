using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;

namespace OnlineCinema.Mvc.Infrastructure;

public sealed class DatabaseInitializer(AppDbContext context)
{
    public async Task InitializeAsync(Func<Task>? seed = null)
    {
        var previousTimeout = context.Database.GetCommandTimeout();
        context.Database.SetCommandTimeout(300);
        // EF Core 8 не блокирует параллельные Migrate. Session-lock остаётся
        // на открытом соединении вне транзакций отдельных миграций.
        var opened = false;
        var locked = false;
        try
        {
            await context.Database.OpenConnectionAsync();
            opened = true;
            await context.Database.ExecuteSqlRawAsync("SELECT pg_advisory_lock(726401990)");
            locked = true;
            await context.Database.MigrateAsync();
            if (seed != null) await seed();
        }
        finally
        {
            try
            {
                if (locked) await context.Database.ExecuteSqlRawAsync("SELECT pg_advisory_unlock(726401990)");
            }
            finally
            {
                try { if (opened) await context.Database.CloseConnectionAsync(); }
                finally { context.Database.SetCommandTimeout(previousTimeout); }
            }
        }
    }
}
