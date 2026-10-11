using OnlineCinema.Domain.Common;

namespace OnlineCinema.Domain.Entities;

public class Seat : Entity
{
    public int Number { get; set; }
    public int Row { get; set; }

    public int HallId { get; set; }
    // EF заполняет обязательную навигацию при загрузке; чтение требует Include/проекции.
    public Hall Hall { get; set; } = null!;

    //public int SeatType { get; set; } - сделать позже
    public int Price { get; set; }
}