using OnlineCinema.Domain.Common;

namespace OnlineCinema.Domain.Entities;

public class MovieGenre : Entity
{
    public int MovieId { get; set; }
    // EF заполняет обязательную навигацию при загрузке; чтение требует Include/проекции.
    public Movie Movie { get; set; } = null!;
    public int GenreId { get; set; }
    // EF заполняет обязательную навигацию при загрузке; чтение требует Include/проекции.
    public Genre Genre { get; set; } = null!;
}
