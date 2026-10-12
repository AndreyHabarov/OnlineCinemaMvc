using OnlineCinema.Mvc.Mapping;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Mvc.Models.ViewModels.Promotions;
using OnlineCinema.Application.Demo;

namespace OnlineCinema.Mvc.Controllers;

public class PromotionsController(AppDbContext context, DemoPromotionCatalog catalog) : BaseMvcController(context)
{
    [Route("promotions")]
    public async Task<IActionResult> Promotions()
    {
        var promotions = await Context.Promotions.AsNoTracking().OrderBy(p => p.DateTime).ThenBy(p => p.Id)
            .Select(ViewProjections.PromotionDetails).ToListAsync();
        return View("Promotions", promotions);
    }
    [Route("promotions/{name}")]
    public async Task<IActionResult> Get(string name)
    {
        var normalized = name.Trim().ToLowerInvariant();
        var promotion = await Context.Promotions.AsNoTracking()
            .Where(p => EF.Property<string>(p, "NormalizedName") == normalized)
            .Select(ViewProjections.PromotionDetails).FirstOrDefaultAsync();
        if (promotion != null) return View("PromotionDetails", promotion);
        var alias = catalog.Items.FirstOrDefault(p => p.LegacySnapshots.Any(s => s.Name.Trim().ToLowerInvariant() == normalized));
        if (alias == null) return NotFound();
        var currentName = await Context.DemoSeedRecords.Where(m => m.Key == "promotion:" + alias.Key)
            .Join(Context.Promotions, m => m.EntityId, p => p.Id, (m, p) => p.Name).FirstOrDefaultAsync();
        return currentName == null ? NotFound() : RedirectToAction(nameof(Get), new { name = currentName });
    }
}
