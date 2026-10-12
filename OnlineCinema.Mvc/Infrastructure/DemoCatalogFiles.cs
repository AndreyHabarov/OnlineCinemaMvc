using OnlineCinema.Application.Demo;

namespace OnlineCinema.Mvc.Infrastructure;

public static class DemoCatalogFiles
{
    public static Task<DemoCatalog> LoadAsync(IWebHostEnvironment environment)
    {
        var data = Path.Combine(environment.ContentRootPath, "data");
        if (!Directory.Exists(data)) data = Path.GetFullPath(Path.Combine(environment.ContentRootPath, "..", "data"));
        return DemoCatalog.LoadAsync(data, environment.WebRootPath);
    }
}
