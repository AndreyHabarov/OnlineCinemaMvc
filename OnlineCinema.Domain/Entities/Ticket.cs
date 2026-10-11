using OnlineCinema.Domain.Common;
using OnlineCinema.Domain.Enums;

namespace OnlineCinema.Domain.Entities;

public class Ticket : Entity
{
    public int Price { get; set; }
    public int Age { get; set; }

    public int SeatId { get; set; }
    // EF заполняет обязательную навигацию при загрузке; чтение требует Include/проекции.
    public Seat Seat { get; set; } = null!;

    public int CustomerId { get; set; }
    // EF заполняет обязательную навигацию при загрузке; чтение требует Include/проекции.
    public Customer Customer { get; set; } = null!;

    public int SessionId { get; set; }
    // EF заполняет обязательную навигацию при загрузке; чтение требует Include/проекции.
    public Session Session { get; set; } = null!;

    public TicketType Status { get; set; }
    public int? PurchaseOrderId { get; set; }
    public PurchaseOrder? PurchaseOrder { get; set; }
}
