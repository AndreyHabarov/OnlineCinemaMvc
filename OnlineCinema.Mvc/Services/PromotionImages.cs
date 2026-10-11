namespace OnlineCinema.Mvc.Services;

public sealed class PromotionImages(IWebHostEnvironment environment, ILogger<PromotionImages> logger)
{
    private const string Prefix = "images/promotion/uploads/";
    public async Task<string> SaveAsync(IFormFile file)
    {
        if (file.Length is <= 16 or > 2097152) throw new ArgumentException("Изображение должно быть не больше 2 МБ.");
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        await using var stream = file.OpenReadStream();
        using var memory = new MemoryStream();
        await stream.CopyToAsync(memory);
        var bytes = memory.ToArray();
        if (bytes.Length > 2097152) throw new ArgumentException("Изображение должно быть не больше 2 МБ.");
        var valid = extension switch
        {
            ".jpg" or ".jpeg" => bytes[0] == 255 && bytes[1] == 216 && bytes[^2] == 255 && bytes[^1] == 217,
            ".png" => bytes.AsSpan(0, 8).SequenceEqual(new byte[] {137,80,78,71,13,10,26,10})
                && bytes.AsSpan(bytes.Length - 8, 4).SequenceEqual("IEND"u8),
            ".webp" => bytes.AsSpan(0,4).SequenceEqual("RIFF"u8) && bytes.AsSpan(8,4).SequenceEqual("WEBP"u8),
            _ => false
        };
        if (!valid) throw new ArgumentException("Допускаются изображения JPEG, PNG и WebP с соответствующим содержимым.");
        var path = Prefix + Guid.NewGuid().ToString("N") + extension;
        var directory = Path.Combine(environment.WebRootPath, "images", "promotion", "uploads");
        Directory.CreateDirectory(directory);
        await File.WriteAllBytesAsync(Path.Combine(directory, Path.GetFileName(path)), bytes);
        return path;
    }

    public void DeleteManaged(string? path)
    {
        if (path == null || !path.StartsWith(Prefix, StringComparison.Ordinal)
            || !System.Text.RegularExpressions.Regex.IsMatch(path[Prefix.Length..], @"^[a-f0-9]{32}\.(jpg|jpeg|png|webp)$")) return;
        try { File.Delete(Path.Combine(environment.WebRootPath, "images", "promotion", "uploads", Path.GetFileName(path))); }
        catch (IOException exception) { logger.LogWarning(exception, "Не удалось удалить старое изображение акции"); }
        catch (UnauthorizedAccessException exception) { logger.LogWarning(exception, "Нет доступа для удаления изображения акции"); }
    }
}
