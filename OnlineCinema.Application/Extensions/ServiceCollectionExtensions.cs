using Microsoft.Extensions.DependencyInjection;
using OnlineCinema.Application.Purchases;
using OnlineCinema.Application.Demo;

namespace OnlineCinema.Application.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddOnlineCinemaApplication(this IServiceCollection services,
        bool isDemo = false, DateTime[]? demoDates = null)
    {
        services.AddSingleton(new SessionAvailability(isDemo, demoDates ?? []));
        services.AddScoped<TicketPurchases>();
        services.AddScoped<DemoSeeder>();
        return services;
    }
}
