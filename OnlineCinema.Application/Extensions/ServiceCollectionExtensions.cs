using Microsoft.Extensions.DependencyInjection;
using OnlineCinema.Application.Purchases;

namespace OnlineCinema.Application.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddOnlineCinemaApplication(this IServiceCollection services)
    {
        services.AddScoped<TicketPurchases>();
        return services;
    }
}