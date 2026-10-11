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

    public async Task<IActionResult> Index()
    {
        var homeViewModel = new HomeViewModel
        {
            Advertisings = await Context.Advertisings.AsNoTracking().OrderBy(a => a.Id)
                .Select(a => a.PathToImage)
                .ToListAsync(),
            Posters = await Context.Movies.AsNoTracking()
                .Where(m => m.IsVisible).OrderBy(m => m.Id)
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
