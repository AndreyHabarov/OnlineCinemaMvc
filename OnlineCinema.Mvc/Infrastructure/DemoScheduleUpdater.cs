using OnlineCinema.Application.Demo;

namespace OnlineCinema.Mvc.Infrastructure;

public sealed class DemoScheduleUpdater(IServiceScopeFactory scopes, IWebHostEnvironment environment,
    IConfiguration configuration, ILogger<DemoScheduleUpdater> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var minutes = configuration.GetValue("Demo:ScheduleRefreshMinutes", 60);
        if (minutes is < 1 or > 1440)
            throw new DemoConfigurationException("Интервал деморасписания должен быть от 1 до 1440 минут.");
        DemoCatalog? catalog = null;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                catalog ??= await DemoCatalogFiles.LoadAsync(environment);
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<DemoSeeder>().RefreshScheduleAsync(catalog);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception exception)
            {
                logger.LogError("Не удалось пополнить деморасписание ({ErrorType}). Следующая попытка через {Minutes} минут.",
                    exception.GetType().Name, minutes);
            }
            try { await Task.Delay(TimeSpan.FromMinutes(minutes), stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
        }
    }
}
