using OnlineCinema.Domain.Common;

namespace OnlineCinema.Domain.Entities;

public class Session : Entity
{
    public DateTime DateStart { get; set; }
    public int Price { get; set; }

    public int MovieId { get; set; }
    // EF заполняет обязательную навигацию при загрузке; чтение требует Include/проекции.
    public Movie Movie { get; set; } = null!;

    public int HallId { get; set; }
    // EF заполняет обязательную навигацию при загрузке; чтение требует Include/проекции.
    public Hall Hall { get; set; } = null!;
}