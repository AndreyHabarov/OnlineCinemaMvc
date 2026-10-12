using System.Text.Json;

namespace OnlineCinema.Application.Demo;

public static class DemoCalendar
{
    private sealed record Calendar(DateOnly[] Dates);

    public static async Task<DateTime[]> LoadAsync(string dataDirectory)
    {
        var calendar = JsonSerializer.Deserialize<Calendar>(
            await File.ReadAllTextAsync(Path.Combine(dataDirectory, "demo-calendar.json")),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        if (calendar?.Dates is not { Length: 7 } dates || dates.Distinct().Count() != 7
            || dates.Any(d => d.Year is < 2000 or > 2099))
            throw new DemoConfigurationException("Демокалендарь должен содержать семь разных дат.");
        return dates.Order().Select(d => d.ToDateTime(TimeOnly.MinValue)).ToArray();
    }
}
