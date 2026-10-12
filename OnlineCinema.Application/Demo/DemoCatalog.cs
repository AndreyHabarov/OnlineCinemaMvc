using System.Text.Json;
using System.Text.RegularExpressions;

namespace OnlineCinema.Application.Demo;

public sealed class DemoMovie
{
    public required string Slug { get; init; }
    public required string Name { get; init; }
    public required string OriginalName { get; init; }
    public DateOnly ReleaseDate { get; init; }
    public int Duration { get; init; }
    public int AgeRating { get; init; }
    public required string Country { get; init; }
    public required string Director { get; init; }
    public required string Actor { get; init; }
    public required string Description { get; init; }
    public required string[] Genres { get; init; }
}

public sealed class DemoHall
{
    public required string Slug { get; init; }
    public required string Name { get; init; }
    public int Rows { get; init; }
    public int SeatsPerRow { get; init; }
    public int Price { get; init; }
    public required string PicturePath { get; init; }
    public required string Description { get; init; }
    public required string[] LegacyDescriptions { get; init; }
}

public sealed record DemoCatalog(IReadOnlyList<DemoMovie> Movies, IReadOnlyDictionary<string, string> Posters,
    IReadOnlyList<DemoHall> Halls, IReadOnlyList<DateTime> Dates)
{
    private sealed class Poster
    {
        public required string Slug { get; init; }
        public required string PosterPath { get; init; }
    }

    public static async Task<DemoCatalog> LoadAsync(string dataDirectory, string webRoot)
    {
        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        var movies = JsonSerializer.Deserialize<List<DemoMovie>>(
            await File.ReadAllTextAsync(Path.Combine(dataDirectory, "demo-movies.json")), options) ?? [];
        var sources = JsonSerializer.Deserialize<List<Poster>>(
            await File.ReadAllTextAsync(Path.Combine(dataDirectory, "movie-poster-sources.json")), options) ?? [];
        if (movies.Count != 36 || movies.Select(m => m.Slug).Distinct().Count() != 36
            || movies.Select(m => m.OriginalName).Distinct().Count() != 36)
            throw new DemoConfigurationException("Демокаталог должен содержать 36 разных фильмов.");
        var posters = sources.ToDictionary(p => p.Slug, p => p.PosterPath);
        foreach (var movie in movies)
        {
            if (!Regex.IsMatch(movie.Slug, "^[a-z0-9-]+$") || movie.ReleaseDate.Year is < 1990 or > 1999
                || movie.Duration <= 0 || movie.AgeRating is < 0 or > 18 || !movie.Country.Contains("США")
                || string.IsNullOrWhiteSpace(movie.Description) || movie.Genres.Length == 0
                || !posters.TryGetValue(movie.Slug, out var path)
                || !Regex.IsMatch(path, @"^images/movies/1990s/[a-z0-9-]+\.(jpg|jpeg|png)$")
                || !File.Exists(Path.Combine(webRoot, path)))
                throw new DemoConfigurationException("Некорректные данные или отсутствующий локальный постер.");
        }
        var halls = JsonSerializer.Deserialize<List<DemoHall>>(
            await File.ReadAllTextAsync(Path.Combine(dataDirectory, "demo-halls.json")), options) ?? [];
        if (halls.Count != 5 || halls.Select(h => h.Slug).Distinct().Count() != halls.Count
            || halls.Select(h => h.Name).Distinct().Count() != halls.Count)
            throw new DemoConfigurationException("Демокаталог должен содержать пять разных залов.");
        foreach (var hall in halls)
            if (!Regex.IsMatch(hall.Slug, "^[a-z0-9-]+$") || string.IsNullOrWhiteSpace(hall.Name)
                || string.IsNullOrWhiteSpace(hall.Description) || hall.Rows is < 1 or > 30
                || hall.SeatsPerRow is < 1 or > 40 || hall.Price is < 1 or > 10000
                || !Regex.IsMatch(hall.PicturePath, @"^/images/hall/[a-z0-9-]+\.png$")
                || !File.Exists(Path.Combine(webRoot, hall.PicturePath.TrimStart('/'))))
                throw new DemoConfigurationException("Некорректные данные или отсутствующая иллюстрация зала.");
        return new(movies, posters, halls, await DemoCalendar.LoadAsync(dataDirectory));
    }
}
