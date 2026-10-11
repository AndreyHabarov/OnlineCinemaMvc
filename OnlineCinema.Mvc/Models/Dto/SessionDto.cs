namespace OnlineCinema.Mvc.Models.Dto;

public sealed class SessionDto
{
    public int Id { get; init; }
    public int MovieId { get; init; }
    public string MovieName { get; init; } = string.Empty;
    public int HallId { get; init; }
    public string HallName { get; init; } = string.Empty;
    public DateTime DateStart { get; init; }
    public int Price { get; init; }
}
