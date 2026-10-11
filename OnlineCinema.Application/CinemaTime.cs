namespace OnlineCinema.Application;

// DateStart хранит московское время кинотеатра без смещения.
public static class CinemaTime
{
    private static readonly TimeZoneInfo Zone = TimeZoneInfo.FindSystemTimeZoneById(
        OperatingSystem.IsWindows() ? "Russian Standard Time" : "Europe/Moscow");

    public static DateTime Now => DateTime.SpecifyKind(
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, Zone), DateTimeKind.Unspecified);
}
