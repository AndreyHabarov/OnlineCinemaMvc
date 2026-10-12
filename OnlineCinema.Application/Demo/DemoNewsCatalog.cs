using System.Text.Json;
using System.Text.RegularExpressions;
using OnlineCinema.Domain.Entities;

namespace OnlineCinema.Application.Demo;

public sealed record NewsSnapshot(string Name, string Description, string ImagePath)
{
    public bool Matches(News news) => news.Name == Name && news.Description == Description
        && news.ImagePath == ImagePath;
}

public sealed record DemoNews(string Key, string Name, string Description, string ImagePath,
    DateTime Date, string MovieSlug, string SourceTitle, string SourceUrl, NewsSnapshot Legacy);

public sealed record DemoNewsCatalog(IReadOnlyList<DemoNews> Items)
{
    public static async Task<DemoNewsCatalog> LoadAsync(string dataDirectory, string webRoot)
    {
        var items = JsonSerializer.Deserialize<List<DemoNews>>(
            await File.ReadAllTextAsync(Path.Combine(dataDirectory, "demo-news.json")),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];
        if (items.Count != 3 || items.Select(n => n.Key).Distinct().Count() != 3)
            throw new DemoConfigurationException("Нужны три разные новости.");
        foreach (var item in items)
            if (!Regex.IsMatch(item.Key, "^[a-z0-9-]+$") || !Regex.IsMatch(item.MovieSlug, "^[a-z0-9-]+$")
                || string.IsNullOrWhiteSpace(item.Name) || string.IsNullOrWhiteSpace(item.Description)
                || item.Legacy == null || string.IsNullOrWhiteSpace(item.SourceTitle)
                || !Uri.TryCreate(item.SourceUrl, UriKind.Absolute, out var source) || source.Scheme != "https"
                || !Regex.IsMatch(item.ImagePath, @"^/images/news/[a-z0-9-]+\.png$")
                || !File.Exists(Path.Combine(webRoot, item.ImagePath.TrimStart('/'))))
                throw new DemoConfigurationException("Некорректная новость или отсутствующая иллюстрация.");
        return new(items);
    }
}
