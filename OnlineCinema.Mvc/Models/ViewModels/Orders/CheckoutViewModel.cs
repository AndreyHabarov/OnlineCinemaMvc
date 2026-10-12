namespace OnlineCinema.Mvc.Models.ViewModels.Orders;

public sealed class CheckoutViewModel
{
    public int SessionId { get; init; }
    public int MovieId { get; init; }
    public string MovieName { get; init; } = string.Empty;
    public int AgeRating { get; init; }
    public string HallName { get; init; } = string.Empty;
    public string HallDescription { get; init; } = string.Empty;
    public string HallPicturePath { get; init; } = string.Empty;
    public DateTime StartsAt { get; init; }
    public List<CheckoutSeat> Seats { get; set; } = [];
}

public sealed class CheckoutSeat
{
    public int Id { get; init; }
    public int Row { get; init; }
    public int Number { get; init; }
    public int Price { get; init; }
    public bool Occupied { get; init; }
}

public sealed class TicketReceiptViewModel
{
    public Guid PublicId { get; init; }
    public string MovieName { get; init; } = string.Empty;
    public string HallName { get; init; } = string.Empty;
    public DateTime StartsAt { get; init; }
    public DateTimeOffset CreatedAt { get; init; }
    public int Total { get; init; }
    public List<ReceiptSeat> Seats { get; init; } = [];
}

public sealed class ReceiptSeat
{
    public int TicketId { get; init; }
    public int Row { get; init; }
    public int Number { get; init; }
    public int Price { get; init; }
}
