using System.ComponentModel.DataAnnotations;

namespace OnlineCinema.Mvc.Models.Dto.Promotions;

using OnlineCinema.Mvc.Services;

public sealed class SavePromotionDto : IValidatableObject
{
    public int Id { get; set; }
    [Required, StringLength(100), RegularExpression(@"^[a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)*$")]
    public string Name { get; set; } = string.Empty;
    [Required, StringLength(150)]
    public string DisplayName { get; set; } = string.Empty;
    [Required, StringLength(5000)]
    public string Description { get; set; } = string.Empty;
    [Required]
    public DateTime? DateTime { get; set; }
    [Required, StringLength(100)]
    public string ButtonText { get; set; } = string.Empty;
    [StringLength(500)]
    public string? Link { get; set; }
    public IFormFile? Image { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (!string.IsNullOrWhiteSpace(Link) && PublicUrls.NavigationLink(Link) is null)
            yield return new ValidationResult("Укажите ссылку HTTP/HTTPS или локальный путь.", new[] { nameof(Link) });
    }
}
