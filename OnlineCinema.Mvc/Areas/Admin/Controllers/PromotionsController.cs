using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OnlineCinema.Domain;
using OnlineCinema.Domain.Common;
using OnlineCinema.Domain.Entities;
using OnlineCinema.Mvc.Controllers;
using OnlineCinema.Mvc.Models.Dto.Common;
using OnlineCinema.Mvc.Models.Dto.Promotions;

namespace OnlineCinema.Mvc.Areas.Admin.Controllers;

[Authorize(Roles = StaticRoleNames.ADMIN)]
[Area("Admin")]
public sealed class PromotionsController : BaseMvcController
{
    private readonly IWebHostEnvironment _webHostEnvironment;
    public PromotionsController(IMapper mapper, AppDbContext context, IWebHostEnvironment webHostEnvironment = null) : base(mapper, context)
    {
        _webHostEnvironment = webHostEnvironment;
    }

    public IActionResult Index()
    {
        return View();
    }

    [HttpPost]
    public IActionResult GetAll([FromBody] PagedSearchRequestDto input)
    {
        IQueryable<Promotion> query = Context.Promotions;
        if (!string.IsNullOrWhiteSpace(input.Keyword))
        {
            query = query.Where(g => g.Name.ToLower().Contains(input.Keyword.ToLower()));
        }

        var totalCount = query.LongCount();

        var entities = query
            .Skip(input.SkipCount)
            .Take(input.PageSize)
            .ToList();

        var dtos = Mapper.Map<IReadOnlyList<PromotionDto>>(entities);
        return Ok(new PagedResultDto<PromotionDto>(totalCount, dtos));
    }

    [HttpGet]
    public IActionResult Get(int id)
    {
        var promotion = Context.Promotions.FirstOrDefault(p => p.Id == id);
        if (promotion is null)
        {
            return NotFound();
        }

        var promotionDto = Mapper.Map<PromotionDto>(promotion);

        return Ok(promotionDto);
    }

    [HttpDelete]
    public IActionResult Delete([FromQuery] int id)
    {
        var promotion = Context.Promotions.FirstOrDefault(p => p.Id == id);

        if (promotion is null)
        {
            return BadRequest();
        }

        Context.Promotions.Remove(promotion);
        Context.SaveChanges();

        return Ok();
    }

    [HttpPut]
    public IActionResult Update([FromBody] PromotionDto updatePromotionDto)
    {
        var files = HttpContext.Request.Form.Files;
        string webRootPath = _webHostEnvironment.WebRootPath;


        var promotion = Context.Promotions.FirstOrDefault(p => p.Id == updatePromotionDto.Id);

        if (promotion is null)
        {
            return BadRequest();
        }

        if (files.Count > 0)
        {
            string upload = webRootPath + WC.ImagePath;
            string fileName = Guid.NewGuid().ToString();
            string extension = Path.GetExtension(files[0].FileName);

            var oldFile = Path.Combine(upload, promotion.ImagePath);

            if (System.IO.File.Exists(oldFile))
            {
                System.IO.File.Delete(oldFile);
            }

            using (var fileStream = new FileStream(Path.Combine(upload, fileName + extension), FileMode.Create))
            {
                files[0].CopyTo(fileStream);
            }

            updatePromotionDto.ImagePath = fileName + extension;
        }
        else
        {
            updatePromotionDto.ImagePath = promotion.ImagePath;
        }

        Mapper.Map(updatePromotionDto, promotion);
        Context.Promotions.Update(promotion);
        Context.SaveChanges();

        return Ok();
    }
}
