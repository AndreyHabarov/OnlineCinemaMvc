using AutoMapper;
using AutoMapper.QueryableExtensions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Mvc.Models.ViewModels.Promotions;

namespace OnlineCinema.Mvc.Controllers;

public class PromotionsController(IMapper mapper, AppDbContext context) : BaseMvcController(mapper, context)
{
    [Route("promotions")]
    public async Task<IActionResult> Promotions()
    {
        var promotions = await Context.Promotions.AsNoTracking().OrderBy(p => p.DateTime).ThenBy(p => p.Id)
            .ProjectTo<PromotionViewModel>(Mapper.ConfigurationProvider).ToListAsync();
        return View("Promotions", promotions);
    }
    [Route("promotions/{name}")]
    public async Task<IActionResult> Get(string name)
    {
        var normalized = name.Trim().ToLower();
        var promotion = await Context.Promotions.AsNoTracking()
            .Where(p => EF.Property<string>(p, "NormalizedName") == normalized)
            .ProjectTo<PromotionViewModel>(Mapper.ConfigurationProvider).FirstOrDefaultAsync();
        return promotion == null ? NotFound() : View("PromotionDetails", promotion);
    }
}
