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
            var hallViewModel = await Context.Halls.AsNoTracking().OrderBy(h => h.Id)
                .Select(h => new HallViewModel
                {
                    Id = h.Id, Name = h.Name, PicturePath = h.PicturePath, Description = h.Description,
                    SeatCount = Context.Seats.Count(s => s.HallId == h.Id),
                    RowCount = Context.Seats.Where(s => s.HallId == h.Id).Select(s => s.Row).Distinct().Count()
                })
                .ToListAsync();

            return View("HallType", hallViewModel);
        }
    }
}
