using System.ComponentModel.DataAnnotations;

namespace OnlineCinema.Mvc.Models.Dto;

public sealed class PurchaseTicketsDto
{
    public Guid RequestId { get; set; }
    [Range(1, int.MaxValue)]
    public int SessionId { get; set; }
    [Required, MinLength(1), MaxLength(6)]
    public int[] SeatIds { get; set; } = [];
    [Range(0, 120)]
    public int ViewerAge { get; set; }
}
