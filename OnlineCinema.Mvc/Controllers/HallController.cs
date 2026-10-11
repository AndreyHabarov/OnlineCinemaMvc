using OnlineCinema.Mvc.Mapping;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Mvc.Models.ViewModels.Hall;

namespace OnlineCinema.Mvc.Controllers
{
    public class HallController : BaseMvcController
    {
        public HallController(AppDbContext context) : base(context)
        {
        }

        [Route("halls")]
        public async Task<IActionResult> GetHalls()
        {
            var hallViewModel = await Context.Halls
                .Select(ViewProjections.Hall)
                .ToListAsync();

            return View("HallType", hallViewModel);
        }
    }
}
