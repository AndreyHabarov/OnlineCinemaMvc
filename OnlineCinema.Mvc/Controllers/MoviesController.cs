using AutoMapper;
using AutoMapper.QueryableExtensions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Domain.Entities;
using OnlineCinema.Mvc.Models.Dto;
using OnlineCinema.Mvc.Models.ViewModels.Hall;
using OnlineCinema.Mvc.Models.ViewModels.Movies;
using System.Globalization;
using OnlineCinema.Mvc.Services;

namespace OnlineCinema.Mvc.Controllers;


public class MoviesController : BaseMvcController
{
    public MoviesController(IMapper mapper, AppDbContext context) : base(mapper, context)
    {
    }

    [Route("movies/{id:int}")]
    public async Task<IActionResult> Get(int? id)
    {
        if (id == null || id < 0)
        {
            return NotFound();
        }

        //Маппинг Movie в MovieViewModel через метод расширение ProjectTo()
        var movieViewModel = await Context.Movies
            .Include(m => m.MovieGenres)
            .ThenInclude(mg => mg.Genre)
            .ProjectTo<MovieViewModel>(Mapper.ConfigurationProvider)
            .FirstOrDefaultAsync(m => m.Id == id && m.IsVisible);

        if (movieViewModel == null)
        {
            return NotFound();
        }

        var dateNow = CinemaTime.Now;

        var sessions = await Context.Sessions
             .Where(s => s.MovieId == id && s.DateStart >= dateNow)
             .Select(s => s.DateStart)
             .OrderBy(s => s)
             .ToListAsync();

        movieViewModel.SessionDates = sessions
            .Select(s => s.Date)
            .Distinct()
            .Take(5)
            .ToArray();

        movieViewModel.Halls = await Context.Halls
            .ProjectTo<HallViewModel>(Mapper.ConfigurationProvider)
            .ToListAsync();

        return View("Movie", movieViewModel);
    }


    [Route("kids")]
    public async Task<IActionResult> KidsMovies()
    {
        var movies = await Context.Movies
            .Where(m => m.IsVisible && m.AgeRating <= 12)
            .ToListAsync();

        var kidsViewModel = Mapper.Map<IEnumerable<KidsViewModel>>(movies);

        if (kidsViewModel == null)
        {
            return NotFound();
        }

        return View("KidsMovies", kidsViewModel);
    }

    [Route("art")]
    public async Task<IActionResult> ArtMovies()
    {
        var movies = await Context.Movies
            .Include(m => m.MovieGenres)
            .ThenInclude(mg => mg.Genre)
            .Where(m => m.IsVisible && m.MovieGenres
            .Any(mg => mg.Genre.Name == "Драма" || mg.Genre.Name == "Криминал"))
            .ToListAsync();

        var movieViewModels = Mapper.Map<IEnumerable<ArtViewModel>>(movies);

        if (movieViewModels == null)
        {
            return NotFound();
        }

        return View("ArtMovies", movieViewModels);
    }

    [HttpGet("[controller]/[action]")]
    public async Task<IActionResult> GetAllSessions([FromQuery] GetAllSessionsDto input)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = "Проверьте параметры фильма и зала." });
        }

        if (!DateTime.TryParseExact(input.Date, "dd.MM.yyyy", CultureInfo.InvariantCulture,
            DateTimeStyles.None, out var inputDate) || inputDate.Date == DateTime.MaxValue.Date)
        {
            return BadRequest(new { message = "Укажите дату в формате ДД.ММ.ГГГГ." });
        }

        var dateEnd = inputDate.AddDays(1);
        var now = CinemaTime.Now;
        var query = Context.Sessions.AsNoTracking()
            .Where(s => s.Movie.IsVisible && s.DateStart >= now
                && s.DateStart >= inputDate && s.DateStart < dateEnd);

        if (input.HallId.HasValue)
        {
            query = query.Where(s => s.HallId == input.HallId);
        }

        if (input.MovieId.HasValue)
        {
            query = query.Where(s => s.MovieId == input.MovieId);
        }

        var sessions = await query.OrderBy(s => s.DateStart).ThenBy(s => s.HallId).ThenBy(s => s.Id)
            .Select(s => new SessionDto
            {
                Id = s.Id, MovieId = s.MovieId, MovieName = s.Movie.Name,
                HallId = s.HallId, HallName = s.Hall.Name,
                DateStart = s.DateStart, Price = s.Price
            }).ToListAsync();

        return Ok(sessions);
    }
}
