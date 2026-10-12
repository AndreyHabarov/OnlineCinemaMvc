using OnlineCinema.Mvc.Mapping;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Mvc.Models.ViewModels.News;
using OnlineCinema.Application.Demo;

namespace OnlineCinema.Mvc.Controllers;

public class NewsController : BaseMvcController
{
    private readonly DemoNewsCatalog _catalog;

    public NewsController(AppDbContext context, DemoNewsCatalog catalog) : base(context)
    {
        _catalog = catalog;
    }

    [Route("news/{id:int}")]
    public async Task<IActionResult> GetNewsById(int? id)
    {
        if (id == null || id < 0)
        {
            return NotFound();
        }

        var newsViewModel = await Context.News.AsNoTracking().OrderByDescending(n => n.Date).ThenByDescending(n => n.Id)
            .Select(ViewProjections.NewsDetails)
            .FirstOrDefaultAsync(n => n.Id == id);

        if (newsViewModel == null)
        {
            return NotFound();
        }

        var key = await Context.DemoSeedRecords.AsNoTracking()
            .Where(s => s.Key.StartsWith("news:") && s.EntityId == newsViewModel.Id)
            .Select(s => s.Key).FirstOrDefaultAsync();
        var reference = _catalog.Items.FirstOrDefault(n => "news:" + n.Key == key
            && n.Name == newsViewModel.Name && n.Description == newsViewModel.Description
            && n.ImagePath == newsViewModel.ImagePath);
        if (reference != null)
        {
            newsViewModel.SourceTitle = reference.SourceTitle;
            newsViewModel.SourceUrl = reference.SourceUrl;
            newsViewModel.IsRetrospective = true;
            var movie = await (from marker in Context.DemoSeedRecords.AsNoTracking()
                join film in Context.Movies.AsNoTracking() on marker.EntityId equals film.Id
                where marker.Key == "movie:" + reference.MovieSlug && film.IsVisible
                select new { film.Id, film.Name }).FirstOrDefaultAsync();
            newsViewModel.MovieId = movie?.Id;
            newsViewModel.MovieName = movie?.Name;
        }
        return View("News", newsViewModel);
    }

    [Route("news")]
    public async Task<IActionResult> GetAll()
    {
        var newsViewModel = await Context.News.AsNoTracking().OrderByDescending(n => n.Date).ThenByDescending(n => n.Id)
            .Select(ViewProjections.NewsDetails)
            .ToListAsync();

        return View("AllNews", newsViewModel);
    }
}
