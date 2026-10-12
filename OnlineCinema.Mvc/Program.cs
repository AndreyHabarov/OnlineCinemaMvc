using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Domain.Entities;
using OnlineCinema.Mvc.Services.CurrentUser;
using System.Globalization;
using Microsoft.AspNetCore.Mvc;
using OnlineCinema.Mvc.Filters;
using Microsoft.AspNetCore.DataProtection;
using OnlineCinema.Application.Extensions;
using Npgsql;

CultureInfo.DefaultThreadCurrentCulture = CultureInfo.GetCultureInfo("ru-RU");
CultureInfo.DefaultThreadCurrentUICulture = CultureInfo.GetCultureInfo("ru-RU");

var builder = WebApplication.CreateBuilder(args);

if (!builder.Environment.IsDevelopment())
{
    // В .NET 8 middleware пишет исключение целиком. Обработчик ErrorController
    // вместо этого журналирует безопасные тип ошибки и идентификатор запроса.
    builder.Logging.AddFilter("Microsoft.AspNetCore.Diagnostics.ExceptionHandlerMiddleware", LogLevel.None);
}

if (builder.Environment.IsDevelopment())
{
    builder.Configuration
        .AddJsonFile("appsettings.Development.local.json", optional: true, reloadOnChange: true)
        .AddEnvironmentVariables()
        .AddCommandLine(args);
}

var keysPath = builder.Configuration["DataProtection:KeysPath"];
if (!string.IsNullOrWhiteSpace(keysPath))
{
    var protection = builder.Services.AddDataProtection()
        .PersistKeysToFileSystem(new DirectoryInfo(keysPath));
    if (OperatingSystem.IsWindows())
        protection.ProtectKeysWithDpapi();
}

var mvc = builder.Services.AddControllersWithViews(options =>
{
    options.Filters.Add(new AutoValidateAntiforgeryTokenAttribute());
    options.Filters.Add(new AntiforgeryErrorFilter());
});
if (builder.Environment.IsDevelopment()) mvc.AddRazorRuntimeCompilation();
builder.Services.AddAntiforgery(options => options.HeaderName = "X-CSRF-TOKEN");

var connectionString = builder.Configuration.GetConnectionString("Default");
if (string.IsNullOrWhiteSpace(connectionString) && !string.IsNullOrWhiteSpace(builder.Configuration["Database:Host"]))
{
    // Раздельные значения правильно экранируются, включая специальные символы пароля.
    connectionString = new NpgsqlConnectionStringBuilder
    {
        Host = builder.Configuration["Database:Host"],
        Port = builder.Configuration.GetValue("Database:Port", 5432),
        Database = builder.Configuration["Database:Name"],
        Username = builder.Configuration["Database:User"],
        Password = builder.Configuration["Database:Password"]
    }.ConnectionString;
}
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "Не задано подключение к PostgreSQL. Выполните scripts/Initialize-Local.ps1 " +
        "или задайте переменную окружения ConnectionStrings__Default.");
}

builder.Services.AddDbContext<AppDbContext>(options => options.UseNpgsql(connectionString));

builder.Services.AddIdentity<User, Role>(opt =>
{
    opt.Password.RequireDigit = true;
    opt.Password.RequireUppercase = true;
    opt.Password.RequireLowercase = true;
    opt.Password.RequireNonAlphanumeric = false;
    opt.SignIn.RequireConfirmedEmail = false;
    opt.User.RequireUniqueEmail = true;
    opt.User.AllowedUserNameCharacters = string.Empty;
    opt.SignIn.RequireConfirmedAccount = false;
    opt.Password.RequiredLength = 8;
    opt.Lockout.MaxFailedAccessAttempts = 5;
    opt.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
    opt.Lockout.AllowedForNewUsers = true;
})
    .AddEntityFrameworkStores<AppDbContext>()
    .AddDefaultTokenProviders();

builder.Services.AddScoped<ICurrentUserService, CurrentUserService>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<OnlineCinema.Mvc.Services.PromotionImages>();
builder.Services.AddOnlineCinemaApplication();
builder.Services.ConfigureApplicationCookie(options =>
{
    options.LoginPath = "/Account/Login";
    options.Events.OnRedirectToAccessDenied = context =>
    {
        context.Response.StatusCode = StatusCodes.Status403Forbidden;
        return Task.CompletedTask;
    };
    options.Events.OnRedirectToLogin = context =>
    {
        if (context.Request.Headers["Accept"].Any(value => value?.Contains("application/json") == true))
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        else
            context.Response.Redirect(context.RedirectUri);
        return Task.CompletedTask;
    };
});

var app = builder.Build();


if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();

app.UseAuthorization();

app.MapGet("/health", async (AppDbContext context, CancellationToken token) =>
    await context.Database.CanConnectAsync(token)
        ? Results.Text("Готов") : Results.StatusCode(StatusCodes.Status503ServiceUnavailable));

app.MapControllerRoute(
    name: "areas",
    pattern: "{area:exists}/{controller=Home}/{action=Index}/{id?}");

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
