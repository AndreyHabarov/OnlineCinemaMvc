using System.Text.Json;
using System.Text.RegularExpressions;
using OnlineCinema.Domain.Entities;

namespace OnlineCinema.Application.Demo;

public sealed record PromotionSnapshot(string Name, string DisplayName, string Description,
    string ImagePath, string ButtonText, string? Link)
{
    public bool Matches(Promotion promotion) => promotion.Name == Name
        && promotion.DisplayName == DisplayName && promotion.Description == Description
        && promotion.ImagePath == ImagePath && promotion.ButtonText == ButtonText
        && promotion.Link == Link;
}

public sealed record DemoPromotion(string Key, string Name, string DisplayName, string Description,
    string ImagePath, string ButtonText, string Link, string? TargetGenreKey, DateTime DateTime,
    PromotionSnapshot[] LegacySnapshots);

public sealed record DemoPromotionCatalog(IReadOnlyList<DemoPromotion> Items)
{
    public static async Task<DemoPromotionCatalog> LoadAsync(string dataDirectory, string webRoot)
    {
        var items = JsonSerializer.Deserialize<List<DemoPromotion>>(
            await File.ReadAllTextAsync(Path.Combine(dataDirectory, "demo-promotions.json")),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];
        if (items.Count != 3 || items.Select(p => p.Key).Distinct().Count() != 3
            || items.Select(p => p.Name).Distinct().Count() != 3)
            throw new DemoConfigurationException("Нужны три разных демопредложения.");
        foreach (var item in items)
            if (!Regex.IsMatch(item.Key, "^[a-z0-9-]+$") || !Regex.IsMatch(item.Name, "^[a-z0-9-]+$")
                || string.IsNullOrWhiteSpace(item.DisplayName) || string.IsNullOrWhiteSpace(item.Description)
                || string.IsNullOrWhiteSpace(item.ButtonText) || item.LegacySnapshots == null
                || !Regex.IsMatch(item.ImagePath, @"^/images/promotion/[a-z0-9-]+\.png$")
                || !File.Exists(Path.Combine(webRoot, item.ImagePath.TrimStart('/')))
                || string.IsNullOrWhiteSpace(item.Link) || !item.Link.StartsWith('/')
                || item.Link.StartsWith("//") || item.Link.Contains('\\') || item.Link.Any(char.IsControl))
                throw new DemoConfigurationException("Некорректное демопредложение или отсутствующая иллюстрация.");
        return new(items);
    }
}
