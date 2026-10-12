using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Mvc.Models.ViewModels.Home;

namespace OnlineCinema.Mvc.ViewComponents;

public class FooterGenresViewComponent(AppDbContext context) : ViewComponent
{
    public async Task<IViewComponentResult> InvokeAsync()
    {
        var genres = await context.Genres.AsNoTracking()
            .Where(g => context.MovieGenres.Any(mg => mg.GenreId == g.Id && mg.Movie.IsVisible))
            .OrderBy(g => g.Name).Take(6).Select(g => new CatalogGenreViewModel(g.Id, g.Name)).ToListAsync();
        return View(genres);
    }
}
