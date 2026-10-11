using Microsoft.EntityFrameworkCore;
using Npgsql;
using OnlineCinema.Domain;
using OnlineCinema.Domain.Entities;
using OnlineCinema.Domain.Enums;


namespace OnlineCinema.Application.Purchases;

public sealed record PurchaseResult(Guid? OrderId, string? Error = null, bool Conflict = false);

public sealed class TicketPurchases(AppDbContext context)
{
    public async Task<PurchaseResult> Purchase(int userId, PurchaseRequest input)
    {
        if (userId <= 0 || input.SessionId <= 0 || input.RequestId == Guid.Empty
            || input.SeatIds is not { Length: >= 1 and <= 6 }
            || input.SeatIds.Any(id => id <= 0) || input.SeatIds.Distinct().Count() != input.SeatIds.Length
            || input.ViewerAge is < 0 or > 120)
            return new(null, "Выберите от 1 до 6 разных мест и укажите возраст зрителя от 0 до 120 лет.");
        var existing = await FindExisting(userId, input.RequestId);
        if (existing != null) return Replay(existing, input);
        var session = await context.Sessions.AsNoTracking().Include(s => s.Movie).Include(s => s.Hall)
            .FirstOrDefaultAsync(s => s.Id == input.SessionId);
        if (session == null || !session.Movie.IsVisible || session.DateStart <= CinemaTime.Now)
            return new(null, "Сеанс недоступен или уже начался.");
        if (input.ViewerAge < session.Movie.AgeRating)
            return new(null, $"Для этого фильма нужен возраст не меньше {session.Movie.AgeRating} лет.");
        var seats = await context.Seats.AsNoTracking().Where(s => input.SeatIds.Contains(s.Id)).ToListAsync();
        if (seats.Count != input.SeatIds.Length || seats.Any(s => s.HallId != session.HallId))
            return new(null, "Выберите существующие места в зале этого сеанса.");
        if (await context.Tickets.AnyAsync(t => t.SessionId == session.Id && input.SeatIds.Contains(t.SeatId)
            && (t.Status == TicketType.Sold || t.Status == TicketType.Booked)))
            return new(null, "Одно из выбранных мест уже занято. Обновите схему зала.", true);
        var user = await context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId);
        if (user?.Email == null) return new(null, "Учётная запись недоступна. Войдите снова.");
        if (session.Price <= 0 || seats.Any(s => s.Price < 0)) return new(null, "Для сеанса не настроена корректная цена.");
        var total = seats.Sum(s => (long)session.Price + s.Price);
        if (total > int.MaxValue) return new(null, "Для сеанса не настроена корректная цена.");
        var customer = new Customer { Email = user.Email };
        var order = new PurchaseOrder
        {
            UserId = userId, SessionId = session.Id, RequestId = input.RequestId,
            Total = (int)total, ViewerAge = input.ViewerAge, CreatedAt = DateTimeOffset.UtcNow,
            MovieName = session.Movie.Name, HallName = session.Hall.Name, StartsAt = session.DateStart,
            Tickets = seats.Select(s => new Ticket
            {
                SeatId = s.Id, SessionId = session.Id, Customer = customer,
                Price = session.Price + s.Price, Age = input.ViewerAge, Status = TicketType.Sold
            }).ToList()
        };
        await using var transaction = await context.Database.BeginTransactionAsync();
        try
        {
            context.PurchaseOrders.Add(order);
            await context.SaveChangesAsync();
            await transaction.CommitAsync();
            return new(order.PublicId);
        }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException { SqlState: "23505" })
        {
            await transaction.RollbackAsync();
            context.ChangeTracker.Clear();
            existing = await FindExisting(userId, input.RequestId);
            return existing != null ? Replay(existing, input)
                : new(null, "Одно из выбранных мест уже занято. Обновите схему зала.", true);
        }
    }

    private Task<PurchaseOrder?> FindExisting(int userId, Guid requestId) => context.PurchaseOrders
        .AsNoTracking().Include(o => o.Tickets).FirstOrDefaultAsync(o => o.UserId == userId && o.RequestId == requestId);

    private static PurchaseResult Replay(PurchaseOrder order, PurchaseRequest input) =>
        order.SessionId == input.SessionId && order.ViewerAge == input.ViewerAge
        && order.Tickets.Select(t => t.SeatId).Order().SequenceEqual(input.SeatIds.Order())
            ? new(order.PublicId) : new(null, "Этот запрос уже использован для другого заказа. Обновите страницу.", true);
}
