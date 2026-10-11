using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using OnlineCinema.Domain;
using OnlineCinema.Domain.Common;
using OnlineCinema.Domain.Entities;
using OnlineCinema.Mvc.Controllers;
using OnlineCinema.Mvc.Models.Dto.Common;
using OnlineCinema.Mvc.Models.Dto.Promotions;
using OnlineCinema.Mvc.Services;
using OnlineCinema.Mvc.Mapping;

namespace OnlineCinema.Mvc.Areas.Admin.Controllers;

[Authorize(Roles = StaticRoleNames.ADMIN)]
[Area("Admin")]
public sealed class PromotionsController(AppDbContext context, PromotionImages images) : BaseMvcController(context)
{
    public IActionResult Index() => View();
    [HttpPost]
    public async Task<IActionResult> GetAll([FromBody] PagedSearchRequestDto input)
    {
        if (!ModelState.IsValid) return BadRequest(new { message = "Размер страницы должен быть от 1 до 100, смещение — от 0 до 100000." });
        var query = Context.Promotions.AsNoTracking();
        var total = await query.LongCountAsync();
        if (!string.IsNullOrWhiteSpace(input.Keyword))
        {
            var keyword = input.Keyword.Trim().ToLower();
            query = query.Where(p => p.Name.ToLower().Contains(keyword) || p.DisplayName.ToLower().Contains(keyword));
        }
        var filtered = await query.LongCountAsync();
        var items = await query.OrderBy(p => p.DisplayName).ThenBy(p => p.Id).Skip(input.SkipCount).Take(input.PageSize)
            .Select(ViewProjections.PromotionDto).ToListAsync();
        return Ok(new PagedResultDto<PromotionDto>(total, items, filtered));
    }
    [HttpGet]
    public async Task<IActionResult> Get(int id)
    {
        var promotion = await Context.Promotions.AsNoTracking().Where(p => p.Id == id)
            .Select(ViewProjections.PromotionDto).FirstOrDefaultAsync();
        return promotion == null ? NotFound(new { message = "Акция не найдена." }) : Ok(promotion);
    }
    [HttpPost, RequestSizeLimit(2200000)]
    public async Task<IActionResult> Create([FromForm] SavePromotionDto input) => await Save(input, false);
    [HttpPut, RequestSizeLimit(2200000)]
    public async Task<IActionResult> Update([FromForm] SavePromotionDto input) => await Save(input, true);

    private async Task<IActionResult> Save(SavePromotionDto input, bool update)
    {
        if (!ModelState.IsValid) return BadRequest(new { message = "Заполните название, описание, дату и текст кнопки. Адрес акции должен содержать латинские буквы, цифры и дефисы; ссылка — HTTP/HTTPS или локальный путь." });
        var promotion = update ? await Context.Promotions.FindAsync(input.Id) : new Promotion
        {
            Name = input.Name.Trim(), DisplayName = input.DisplayName.Trim(),
            Description = input.Description.Trim(), ButtonText = input.ButtonText.Trim(),
            // Новый файл проверяется и сохраняется до добавления сущности в БД.
            ImagePath = string.Empty
        };
        if (promotion == null) return NotFound(new { message = "Акция не найдена." });
        if (!update && input.Image == null) return BadRequest(new { message = "Для новой акции загрузите изображение." });
        var oldPath = promotion.ImagePath;
        string? newPath = null;
        if (input.Image != null)
        {
            try { newPath = await images.SaveAsync(input.Image); }
            catch (ArgumentException exception) { return BadRequest(new { message = exception.Message }); }
        }
        promotion.Name = input.Name.Trim();
        promotion.DisplayName = input.DisplayName.Trim();
        promotion.Description = input.Description.Trim();
        promotion.ButtonText = input.ButtonText.Trim();
        promotion.Link = string.IsNullOrWhiteSpace(input.Link) ? null : input.Link.Trim();
        promotion.DateTime = DateTime.SpecifyKind(input.DateTime!.Value, DateTimeKind.Unspecified);
        promotion.ImagePath = newPath ?? oldPath;
        if (!update) Context.Promotions.Add(promotion);
        try { await Context.SaveChangesAsync(); }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException { SqlState: "23505" })
        {
            images.DeleteManaged(newPath);
            return Conflict(new { message = "Адрес акции уже используется. Выберите другой." });
        }
        catch { images.DeleteManaged(newPath); throw; }
        if (newPath != null && !await Context.Promotions.AnyAsync(p => p.ImagePath == oldPath)) images.DeleteManaged(oldPath);
        return Ok(new { promotion.Id });
    }
    [HttpDelete]
    public async Task<IActionResult> Delete(int id)
    {
        var promotion = await Context.Promotions.FindAsync(id);
        if (promotion == null) return NotFound(new { message = "Акция не найдена." });
        Context.Promotions.Remove(promotion);
        await Context.SaveChangesAsync();
        if (!await Context.Promotions.AnyAsync(p => p.ImagePath == promotion.ImagePath)) images.DeleteManaged(promotion.ImagePath);
        return Ok();
    }
}
