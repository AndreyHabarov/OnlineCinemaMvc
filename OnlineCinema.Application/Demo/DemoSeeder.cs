using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Domain.Common;
using OnlineCinema.Domain.Entities;

namespace OnlineCinema.Application.Demo;

public sealed record DemoAdminOptions(bool Enabled, string? Email, string? Password);

public sealed class DemoSeeder(AppDbContext context, RoleManager<Role> roles, UserManager<User> users,
    MovieCastCatalog casts, DemoPromotionCatalog promotions, DemoNewsCatalog newsCatalog)
{
    public async Task EnsureRolesAsync()
    {
        if (!await roles.RoleExistsAsync(StaticRoleNames.ADMIN))
            Require(await roles.CreateAsync(new Role { Name = StaticRoleNames.ADMIN }));
    }

    public async Task SeedAsync(DemoCatalog catalog, DemoAdminOptions admin)
    {
        await using var transaction = await context.Database.BeginTransactionAsync();
        await context.Database.ExecuteSqlRawAsync("SELECT pg_advisory_xact_lock(726401991)");
        await EnsureRolesAsync();
        foreach (var data in catalog.Movies)
        {
            var movie = await EnsureAsync("movie:" + data.Slug,
                () => context.Movies.FirstOrDefaultAsync(m => m.OriginalName == data.OriginalName),
                () => new Movie
                {
                    Name = data.Name, OriginalName = data.OriginalName, Description = data.Description,
                    Duration = data.Duration, AgeRating = data.AgeRating, Country = data.Country,
                    Director = data.Director, Actor = data.Actor, PremiereDate = data.ReleaseDate,
                    WorldPremiere = data.ReleaseDate, PosterPath = catalog.Posters[data.Slug],
                    CardImagePath = catalog.Posters[data.Slug], IsVisible = true
                });
            if (movie.Created && movie.Entity != null)
            {
                foreach (var name in data.Genres.Distinct())
                {
                    var normalized = name.Trim().ToLowerInvariant();
                    var genre = await EnsureAsync("genre:" + normalized,
                        () => context.Genres.FirstOrDefaultAsync(g => EF.Property<string>(g, "NormalizedName") == normalized),
                        () => new Genre { Name = name.Trim() });
                    if (genre.Entity != null)
                        context.MovieGenres.Add(new MovieGenre { MovieId = movie.Entity.Id, GenreId = genre.Entity.Id });
                }
                await context.SaveChangesAsync();
            }
            if (movie.Entity != null && !await HasMarkerAsync("cast:v1:" + data.Slug))
            {
                var cast = casts.Find(data.OriginalName);
                if (cast != null && cast.LegacyActors.Contains(movie.Entity.Actor))
                    movie.Entity.Actor = casts.ActorNames(cast);
                Mark("cast:v1:" + data.Slug, movie.Entity.Id);
                await context.SaveChangesAsync();
            }
        }
        foreach (var hall in catalog.Halls)
        {
            var result = await EnsureAsync("hall:" + hall.Slug,
                () => context.Halls.FirstOrDefaultAsync(h => h.Name == hall.Name),
                () => new Hall { Name = hall.Name, PicturePath = hall.PicturePath, Description = hall.Description });
            if (result.Entity != null && !await HasMarkerAsync("hall-presentation:v2:" + hall.Slug))
            {
                // Обновляем только прежний демоконтент; пользовательские правки сохраняются.
                if (hall.LegacyDescriptions.Contains(result.Entity.Description)) result.Entity.Description = hall.Description;
                if (result.Entity.PicturePath == $"/images/hall/{hall.Slug}.jpg") result.Entity.PicturePath = hall.PicturePath;
                Mark("hall-presentation:v2:" + hall.Slug, result.Entity.Id);
                await context.SaveChangesAsync();
            }
            if (result.Entity == null || await HasMarkerAsync("layout:" + hall.Slug)) continue;
            if (!await context.Seats.AnyAsync(s => s.HallId == result.Entity.Id))
                for (var row = 1; row <= hall.Rows; row++)
                    for (var seat = 1; seat <= hall.SeatsPerRow; seat++)
                        context.Seats.Add(new Seat { HallId = result.Entity.Id, Row = row, Number = seat, Price = 0 });
            Mark("layout:" + hall.Slug, result.Entity.Id);
            await context.SaveChangesAsync();
        }
        const string banner = "/images/demo/cinema-1990s.svg";
        await EnsureAsync("advertising:1990s",
            () => context.Advertisings.FirstOrDefaultAsync(a => a.PathToImage == banner),
            () => new Advertising { PathToImage = banner });
        await SeedPromotionsAsync();
        await SeedNewsAsync();
        await SeedAdminAsync(admin);
        await PopulateScheduleAsync(catalog);
        await transaction.CommitAsync();
    }

    public async Task RefreshScheduleAsync(DemoCatalog catalog)
    {
        await using var transaction = await context.Database.BeginTransactionAsync();
        await context.Database.ExecuteSqlRawAsync("SELECT pg_advisory_xact_lock(726401991)");
        await PopulateScheduleAsync(catalog);
        await transaction.CommitAsync();
    }

    private async Task SeedNewsAsync()
    {
        foreach (var data in newsCatalog.Items)
        {
            var result = await EnsureAsync("news:" + data.Key,
                () => context.News.FirstOrDefaultAsync(n => n.Name == data.Name
                    || (n.Name == data.Legacy.Name && n.Description == data.Legacy.Description
                        && n.ImagePath == data.Legacy.ImagePath)),
                () => new News { Name = data.Name, Description = data.Description,
                    ImagePath = data.ImagePath, Date = data.Date });
            if (result.Entity == null || await HasMarkerAsync("news-presentation:v1:" + data.Key)) continue;
            if (data.Legacy.Matches(result.Entity))
            {
                result.Entity.Name = data.Name;
                result.Entity.Description = data.Description;
                result.Entity.ImagePath = data.ImagePath;
            }
            Mark("news-presentation:v1:" + data.Key, result.Entity.Id);
            await context.SaveChangesAsync();
        }
    }
    private async Task SeedPromotionsAsync()
    {
        foreach (var data in promotions.Items)
        {
            var genre = data.TargetGenreKey == null ? null : await FindMarkedAsync<Genre>("genre:" + data.TargetGenreKey);
            var link = genre == null ? data.Link : $"/?genreId={genre.Id}#movie-catalog";
            var result = await EnsureAsync("promotion:" + data.Key, () => FindPromotionAsync(data),
                () => new Promotion
                {
                    Name = data.Name, DisplayName = data.DisplayName, Description = data.Description,
                    ImagePath = data.ImagePath, ButtonText = data.ButtonText, Link = link, DateTime = data.DateTime
                });
            if (result.Entity == null || await HasMarkerAsync("promotion-presentation:v2:" + data.Key)) continue;
            // Перезаписываем только целиком распознанный прежний шаблон.
            if (data.LegacySnapshots.Any(snapshot => snapshot.Matches(result.Entity)))
            {
                result.Entity.Name = data.Name;
                result.Entity.DisplayName = data.DisplayName;
                result.Entity.Description = data.Description;
                result.Entity.ImagePath = data.ImagePath;
                result.Entity.ButtonText = data.ButtonText;
                result.Entity.Link = link;
            }
            Mark("promotion-presentation:v2:" + data.Key, result.Entity.Id);
            await context.SaveChangesAsync();
        }
    }

    private async Task<Promotion?> FindPromotionAsync(DemoPromotion data)
    {
        var existing = await context.Promotions.FirstOrDefaultAsync(p =>
            EF.Property<string>(p, "NormalizedName") == data.Name);
        if (existing != null) return existing;
        foreach (var snapshot in data.LegacySnapshots)
        {
            var name = snapshot.Name.Trim().ToLowerInvariant();
            existing = await context.Promotions.FirstOrDefaultAsync(p => EF.Property<string>(p, "NormalizedName") == name);
            if (existing != null && snapshot.Matches(existing)) return existing;
        }
        return null;
    }

    private async Task PopulateScheduleAsync(DemoCatalog catalog)
    {
        foreach (var date in catalog.Dates)
        {
            var dayNumber = (int)(date - new DateTime(2000, 1, 1)).TotalDays;
            for (var slot = 0; slot < 4; slot++)
                for (var hallNumber = 0; hallNumber < catalog.Halls.Count; hallNumber++)
                {
                    var start = date.AddHours(10 + 4 * slot);
                    var hallData = catalog.Halls[hallNumber];
                    var key = $"session:{date:yyyyMMdd}:{hallData.Slug}:{slot}";
                    if (await HasMarkerAsync(key)) continue;
                    var movieData = catalog.Movies[(dayNumber * catalog.Halls.Count * 4 + hallNumber * 4 + slot) % catalog.Movies.Count];
                    var movie = await FindMarkedAsync<Movie>("movie:" + movieData.Slug);
                    var hall = await FindMarkedAsync<Hall>("hall:" + hallData.Slug);
                    if (movie is not { IsVisible: true } || movie.Duration <= 0 || hall == null
                        || !await context.Seats.AnyAsync(s => s.HallId == hall.Id)) continue;
                    var existing = await context.Sessions.FirstOrDefaultAsync(s => s.HallId == hall.Id && s.DateStart == start);
                    if (existing != null) { Mark(key, existing.Id); await context.SaveChangesAsync(); continue; }
                    var end = start.AddMinutes(movie.Duration + 30);
                    if (await context.Sessions.AnyAsync(s => s.HallId == hall.Id
                        && s.DateStart < end && s.DateStart.AddMinutes(s.Movie.Duration + 30) > start)) continue;
                    var session = new Session { MovieId = movie.Id, HallId = hall.Id, DateStart = start, Price = hallData.Price };
                    context.Sessions.Add(session);
                    await context.SaveChangesAsync();
                    Mark(key, session.Id);
                    await context.SaveChangesAsync();
                }
        }
    }

    private async Task SeedAdminAsync(DemoAdminOptions options)
    {
        const string key = "account:demo-admin";
        if (!options.Enabled || await HasMarkerAsync(key)) return;
        if (string.IsNullOrWhiteSpace(options.Email) || string.IsNullOrWhiteSpace(options.Password))
            throw new DemoConfigurationException("Для демоадминистратора задайте email и пароль.");
        // Существующему пользователю нельзя автоматически выдать полномочия.
        if (await users.FindByEmailAsync(options.Email.Trim()) != null)
            throw new DemoConfigurationException("Email демоадминистратора уже используется; выберите другой.");
        var user = new User { Name = "Демо", LastName = "Администратор", UserName = options.Email.Trim(), Email = options.Email.Trim() };
        Require(await users.CreateAsync(user, options.Password));
        Require(await users.AddToRoleAsync(user, StaticRoleNames.ADMIN));
        Mark(key, user.Id);
        await context.SaveChangesAsync();
    }

    private async Task<(T? Entity, bool Created)> EnsureAsync<T>(string key, Func<Task<T?>> find, Func<T> create) where T : Entity
    {
        var marker = await context.DemoSeedRecords.FindAsync(key);
        if (marker != null) return (await context.Set<T>().FindAsync(marker.EntityId), false);
        var entity = await find();
        var created = entity == null;
        if (entity == null) { entity = create(); context.Set<T>().Add(entity); await context.SaveChangesAsync(); }
        Mark(key, entity.Id);
        await context.SaveChangesAsync();
        return (entity, created);
    }

    private async Task<T?> FindMarkedAsync<T>(string key) where T : Entity
    {
        var marker = await context.DemoSeedRecords.FindAsync(key);
        return marker == null ? null : await context.Set<T>().FindAsync(marker.EntityId);
    }
    private Task<bool> HasMarkerAsync(string key) => context.DemoSeedRecords.AnyAsync(s => s.Key == key);
    private void Mark(string key, int id) => context.DemoSeedRecords.Add(new DemoSeedRecord { Key = key, EntityId = id });
    private static void Require(IdentityResult result)
    {
        if (!result.Succeeded) throw new DemoConfigurationException("Не удалось создать демоучётную запись или роль; проверьте настройки Identity.");
    }
}
