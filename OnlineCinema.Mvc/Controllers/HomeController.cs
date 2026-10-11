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
            Advertisings = await Context.Advertisings
                .Select(a => a.PathToImage)
                .ToListAsync(),
            Posters = await Context.Movies.AsNoTracking()
                .Where(m => m.IsVisible == true)
                .Select(ViewProjections.HomePoster).ToListAsync(),
            Promotions = await Context.Promotions.AsNoTracking()
                .Select(ViewProjections.HomePromotion).ToListAsync(),
            News = await Context.News.AsNoTracking()
                .Select(ViewProjections.HomeNews)
                .Take(3).ToListAsync()
        };

        return View(homeViewModel);
    }
}
