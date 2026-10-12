using System.Text.Json;
using System.Text.RegularExpressions;

namespace OnlineCinema.Application.Demo;

public sealed record ActorPhoto(string Slug, string Name, string PhotoPath, string SourcePage,
    string Photographer, string License, string LicenseUrl);

public sealed record MovieCast(string Slug, string OriginalName, string[] Actors,
    string[] LegacyActors, bool IsVoiceCast, string SourcePage);

public sealed class MovieCastCatalog
{
    private readonly Dictionary<string, MovieCast> movies;
    private readonly Dictionary<string, ActorPhoto> photos;

    private MovieCastCatalog(List<MovieCast> casts, List<ActorPhoto> actors)
    {
        movies = casts.ToDictionary(m => m.OriginalName, StringComparer.Ordinal);
        photos = actors.ToDictionary(a => a.Slug, StringComparer.Ordinal);
    }

    public MovieCast? Find(string originalName) => movies.GetValueOrDefault(originalName);
    public IReadOnlyList<ActorPhoto> Photos(MovieCast cast) => cast.Actors.Select(slug => photos[slug]).ToArray();
    public string ActorNames(MovieCast cast) => string.Join(", ", Photos(cast).Select(a => a.Name));

    public static async Task<MovieCastCatalog> LoadAsync(string dataDirectory, string webRoot)
    {
        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        var casts = JsonSerializer.Deserialize<List<MovieCast>>(
            await File.ReadAllTextAsync(Path.Combine(dataDirectory, "movie-casts.json")), options) ?? [];
        var actors = JsonSerializer.Deserialize<List<ActorPhoto>>(
            await File.ReadAllTextAsync(Path.Combine(dataDirectory, "actor-photo-sources.json")), options) ?? [];
        if (casts.Count != 36 || casts.Select(m => m.Slug).Distinct().Count() != 36
            || casts.Select(m => m.OriginalName).Distinct().Count() != 36
            || actors.Select(a => a.Slug).Distinct().Count() != actors.Count)
            throw new DemoConfigurationException("Некорректный каталог исполнителей.");
        foreach (var actor in actors)
            if (string.IsNullOrWhiteSpace(actor.Name) || string.IsNullOrWhiteSpace(actor.Photographer)
                || string.IsNullOrWhiteSpace(actor.License)
                || !Regex.IsMatch(actor.PhotoPath, @"^images/actors/[a-z0-9-]+\.(jpg|jpeg|png)$")
                || !File.Exists(Path.Combine(webRoot, actor.PhotoPath))
                || !Uri.TryCreate(actor.SourcePage, UriKind.Absolute, out var source)
                || source.Scheme != Uri.UriSchemeHttps || source.Host != "commons.wikimedia.org"
                || !Uri.TryCreate(actor.LicenseUrl, UriKind.Absolute, out var license)
                || license.Scheme != Uri.UriSchemeHttps)
                throw new DemoConfigurationException("Отсутствует фото или атрибуция исполнителя.");
        var catalog = new MovieCastCatalog(casts, actors);
        foreach (var cast in casts)
            if (cast.Actors.Length < 5 || cast.Actors.Distinct().Count() != cast.Actors.Length
                || cast.Actors.Any(slug => !catalog.photos.ContainsKey(slug)))
                throw new DemoConfigurationException("Для фильма нужны пять разных исполнителей с фото.");
        return catalog;
    }
}
