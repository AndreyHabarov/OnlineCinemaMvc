using OnlineCinema.Domain.Common;
using OnlineCinema.Domain.Enums;

namespace OnlineCinema.Domain.Entities;

public class Ticket : Entity
{
    public int Price { get; set; }
    public int Age { get; set; }

    public int SeatId { get; set; }
    public Seat Seat { get; set; }

    public int CustomerId { get; set; }
    public Customer Customer { get; set; }

    public int SessionId { get; set; }
    public Session Session { get; set; }

    public TicketType Status { get; set; }
    public int? PurchaseOrderId { get; set; }
    public PurchaseOrder? PurchaseOrder { get; set; }
}
