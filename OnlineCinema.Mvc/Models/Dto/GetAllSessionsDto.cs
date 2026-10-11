using System.ComponentModel.DataAnnotations;

namespace OnlineCinema.Mvc.Models.Dto;

public class GetAllSessionsDto
{
    [Range(1, int.MaxValue, ErrorMessage = "Некорректный фильм.")]
    public int? MovieId { get; set; }
    public string? Date { get; set; }
    [Range(1, int.MaxValue, ErrorMessage = "Некорректный зал.")]
    public int? HallId { get; set; }
}
