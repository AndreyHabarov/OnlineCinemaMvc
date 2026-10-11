using OnlineCinema.Domain.Common;

namespace OnlineCinema.Domain.Entities;

public sealed class PurchaseOrder : Entity
{
    public Guid PublicId { get; set; } = Guid.NewGuid();
    public Guid RequestId { get; set; }
    public int UserId { get; set; }
    public User User { get; set; } = null!;
    public int SessionId { get; set; }
    public Session Session { get; set; } = null!;
    public int Total { get; set; }
    public int ViewerAge { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public string MovieName { get; set; } = string.Empty;
    public string HallName { get; set; } = string.Empty;
    public DateTime StartsAt { get; set; }
    public ICollection<Ticket> Tickets { get; set; } = new List<Ticket>();
}
