using OnlineCinema.Application.Demo;

namespace OnlineCinema.Mvc.Infrastructure;

public static class DemoCatalogFiles
{
    public static string GetDataDirectory(IWebHostEnvironment environment)
    {
        var data = Path.Combine(environment.ContentRootPath, "data");
        if (!Directory.Exists(data)) data = Path.GetFullPath(Path.Combine(environment.ContentRootPath, "..", "data"));
        return data;
    }

    public static Task<DemoCatalog> LoadAsync(IWebHostEnvironment environment) =>
        DemoCatalog.LoadAsync(GetDataDirectory(environment), environment.WebRootPath);
}
