namespace OnlineCinema.Application.Purchases;

// Прикладная команда не зависит от HTTP, MVC или правил отображения формы.
public sealed record PurchaseRequest(Guid RequestId, int SessionId, int[] SeatIds, int ViewerAge);
