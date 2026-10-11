using OnlineCinema.Mvc.Models.Dto.Common;

namespace OnlineCinema.Mvc.Models.Dto.Genres;

public sealed class GenreDto : EntityDto
{
    [System.ComponentModel.DataAnnotations.Required]
    [System.ComponentModel.DataAnnotations.StringLength(80)]
    public string Name { get; set; } = string.Empty;
}
