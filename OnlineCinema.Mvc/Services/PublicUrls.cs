namespace OnlineCinema.Mvc.Services;

public static class PublicUrls
{
    public static string? NavigationLink(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        value = value.Trim();
        if (value.Any(char.IsControl) || value.Contains('\\')) return null;
        if (value.StartsWith('/') && !value.StartsWith("//")) return value;
        if (Uri.TryCreate(value, UriKind.Absolute, out var uri)
            && uri.Scheme is "http" or "https" && !string.IsNullOrEmpty(uri.Host)
            && uri.IsWellFormedOriginalString()) return value;
        return null;
    }
}
