using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using OnlineCinema.Domain;
using OnlineCinema.Domain.Common;
using OnlineCinema.Domain.Entities;
using OnlineCinema.Mvc.Controllers;
using OnlineCinema.Mvc.Models.Dto.Common;
using OnlineCinema.Mvc.Models.Dto.Genres;

namespace OnlineCinema.Mvc.Areas.Admin.Controllers;

[Authorize(Roles = StaticRoleNames.ADMIN)]
[Area("Admin")]
public sealed class GenresController(AppDbContext context) : BaseMvcController(context)
{
    public IActionResult Index() => View();

    [HttpGet]
    public async Task<IActionResult> Get(int id)
    {
        var genre = await Context.Genres.AsNoTracking().Where(g => g.Id == id)
            .Select(g => new GenreDto { Id = g.Id, Name = g.Name }).FirstOrDefaultAsync();
        return genre == null ? NotFound(new { message = "Жанр не найден." }) : Ok(genre);
    }

    [HttpPost]
    public async Task<IActionResult> GetAll([FromBody] PagedSearchRequestDto input)
    {
        if (!ModelState.IsValid) return BadRequest(new { message = "Размер страницы должен быть от 1 до 100, смещение — от 0 до 100000." });
        var query = Context.Genres.AsNoTracking();
        var total = await query.LongCountAsync();
        if (!string.IsNullOrWhiteSpace(input.Keyword))
        {
            var keyword = input.Keyword.Trim().ToLower();
            query = query.Where(g => g.Name.ToLower().Contains(keyword));
        }
        var filtered = await query.LongCountAsync();
        var items = await query.OrderBy(g => g.Name).ThenBy(g => g.Id).Skip(input.SkipCount).Take(input.PageSize)
            .Select(g => new GenreDto { Id = g.Id, Name = g.Name }).ToListAsync();
        return Ok(new PagedResultDto<GenreDto>(total, items, filtered));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] GenreDto input) => await Save(input, false);
    [HttpPut]
    public async Task<IActionResult> Update([FromBody] GenreDto input) => await Save(input, true);

    private async Task<IActionResult> Save(GenreDto input, bool update)
    {
        if (!ModelState.IsValid) return BadRequest(new { message = "Название жанра обязательно и должно быть не длиннее 80 символов." });
        var entity = update ? await Context.Genres.FindAsync(input.Id) : new Genre { Name = input.Name.Trim() };
        if (entity == null) return NotFound(new { message = "Жанр не найден." });
        entity.Name = input.Name.Trim();
        if (!update) Context.Genres.Add(entity);
        try { await Context.SaveChangesAsync(); }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: "23505" })
        { return Conflict(new { message = "Жанр с таким названием уже существует." }); }
        return Ok(new { entity.Id });
    }

    [HttpDelete]
    public async Task<IActionResult> Delete(int id)
    {
        var genre = await Context.Genres.FindAsync(id);
        if (genre == null) return NotFound(new { message = "Жанр не найден." });
        if (await Context.MovieGenres.AnyAsync(g => g.GenreId == id))
            return Conflict(new { message = "Этот жанр используется фильмами. Сначала измените их жанры." });
        Context.Genres.Remove(genre);
        try { await Context.SaveChangesAsync(); }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException { SqlState: "23503" })
        { return Conflict(new { message = "Этот жанр уже используется фильмами." }); }
        return Ok();
    }
}
