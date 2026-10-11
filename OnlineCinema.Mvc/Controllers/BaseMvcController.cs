using Microsoft.AspNetCore.Mvc;
using OnlineCinema.Domain;

namespace OnlineCinema.Mvc.Controllers;

public abstract class BaseMvcController : Controller
{
    protected AppDbContext Context { get; set; }

    protected BaseMvcController(AppDbContext context)
    {
        Context = context;
    }
}
