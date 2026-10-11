using OnlineCinema.Mvc.Mapping;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Mvc.Models.ViewModels.News;

namespace OnlineCinema.Mvc.Controllers;

public class NewsController : BaseMvcController
{
    public NewsController(AppDbContext context) : base(context)
    {
    }

    [Route("news/{id:int}")]
    public async Task<IActionResult> GetNewsById(int? id)
    {
        if (id == null || id < 0)
        {
            return NotFound();
        }

        var newsViewModel = await Context.News
            .Select(ViewProjections.NewsDetails)
            .FirstOrDefaultAsync(n => n.Id == id);

        if (newsViewModel == null)
        {
            return NotFound();
        }

        return View("News", newsViewModel);
    }

    [Route("news")]
    public async Task<IActionResult> GetAll()
    {
        var newsViewModel = await Context.News
            .Select(ViewProjections.NewsDetails)
            .ToListAsync();

        return View("AllNews", newsViewModel);
    }
}