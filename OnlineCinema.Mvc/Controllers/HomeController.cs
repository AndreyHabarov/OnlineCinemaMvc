using OnlineCinema.Mvc.Mapping;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Mvc.Models.ViewModels.Home;

namespace OnlineCinema.Mvc.Controllers;

public class HomeController : BaseMvcController
{
    public HomeController(AppDbContext context) : base(context)
    {
    }

    public async Task<IActionResult> Index(string? search, int? genreId, int page = 1)
    {
        const int pageSize = 12;
        search = search?.Trim() ?? string.Empty;
        if (search.Length > 100) search = search[..100];
        var movies = Context.Movies.AsNoTracking().Where(m => m.IsVisible);
        if (search.Length > 0)
        {
            // Contains переводится в SQL и ищет буквальное значение, включая % и _.
            var term = search.ToLowerInvariant();
            movies = movies.Where(m => m.Name.ToLower().Contains(term) || m.OriginalName.ToLower().Contains(term));
        }
        if (genreId.HasValue)
            movies = movies.Where(m => m.MovieGenres.Any(g => g.GenreId == genreId.Value));
        var totalCount = await movies.CountAsync();
        var pageCount = Math.Max(1, (int)Math.Ceiling(totalCount / (double)pageSize));
        page = Math.Clamp(page, 1, pageCount);
        var homeViewModel = new HomeViewModel
        {
            Search = search, GenreId = genreId, Page = page, PageCount = pageCount, TotalCount = totalCount,
            Genres = await Context.Genres.AsNoTracking()
                .Where(g => Context.MovieGenres.Any(mg => mg.GenreId == g.Id && mg.Movie.IsVisible))
                .OrderBy(g => g.Name).Select(g => new CatalogGenreViewModel(g.Id, g.Name)).ToListAsync(),
            FeaturedPosters = await Context.Movies.AsNoTracking().Where(m => m.IsVisible)
                .OrderBy(m => m.Id).Take(3).Select(ViewProjections.HomePoster).ToListAsync(),
            Advertisings = await Context.Advertisings.AsNoTracking().OrderBy(a => a.Id)
                .Select(a => a.PathToImage)
                .ToListAsync(),
            Posters = await movies.OrderBy(m => m.Id).Skip((page - 1) * pageSize).Take(pageSize)
                .Select(ViewProjections.HomePoster).ToListAsync(),
            Promotions = await Context.Promotions.AsNoTracking().OrderBy(p => p.DateTime).ThenBy(p => p.Id)
                .Select(ViewProjections.HomePromotion).ToListAsync(),
            News = await Context.News.AsNoTracking().OrderByDescending(n => n.Date).ThenByDescending(n => n.Id)
                .Select(ViewProjections.HomeNews)
                .Take(3).ToListAsync()
        };

        return View(homeViewModel);
    }
}
