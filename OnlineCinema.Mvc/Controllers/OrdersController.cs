using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Domain.Enums;
using OnlineCinema.Mvc.Models.Dto;
using OnlineCinema.Mvc.Models.ViewModels.Orders;
using OnlineCinema.Mvc.Services;
using OnlineCinema.Mvc.Services.CurrentUser;
using OnlineCinema.Application;
using OnlineCinema.Application.Purchases;

namespace OnlineCinema.Mvc.Controllers;

[Authorize]
public sealed class OrdersController(AppDbContext context, ICurrentUserService currentUser,
    TicketPurchases purchases) : BaseMvcController(context)
{
    [HttpGet("orders/{id:int}")]
    public async Task<IActionResult> Index(int id)
    {
        var now = CinemaTime.Now;
        var session = await Context.Sessions.AsNoTracking()
            .Where(s => s.Id == id && s.Movie.IsVisible && s.DateStart > now)
            .Select(s => new { s.Id, s.HallId, s.Price, s.DateStart, MovieName = s.Movie.Name,
                s.Movie.AgeRating, HallName = s.Hall.Name }).FirstOrDefaultAsync();
        if (session == null) return NotFound();
        var model = new CheckoutViewModel
        {
            SessionId = session.Id, MovieName = session.MovieName, HallName = session.HallName,
            StartsAt = session.DateStart, AgeRating = session.AgeRating,
            Seats = await Context.Seats.AsNoTracking().Where(s => s.HallId == session.HallId)
                .OrderBy(s => s.Row).ThenBy(s => s.Number).Select(s => new CheckoutSeat
                {
                    Id = s.Id, Row = s.Row, Number = s.Number, Price = session.Price + s.Price,
                    Occupied = Context.Tickets.Any(t => t.SessionId == id && t.SeatId == s.Id
                        && (t.Status == TicketType.Sold || t.Status == TicketType.Booked))
                }).ToListAsync()
        };
        return View(model);
    }

    [HttpPost("orders/purchase")]
    public async Task<IActionResult> Purchase([FromBody] PurchaseTicketsDto input)
    {
        if (!ModelState.IsValid || input.RequestId == Guid.Empty || input.SeatIds.Any(id => id <= 0)
            || input.SeatIds.Distinct().Count() != input.SeatIds.Length)
            return BadRequest(new { message = "Выберите от 1 до 6 разных мест и укажите возраст зрителя от 0 до 120 лет." });
        if (currentUser.UserId is not int userId) return Unauthorized();
        var result = await purchases.Purchase(userId,
            new PurchaseRequest(input.RequestId, input.SessionId, input.SeatIds, input.ViewerAge));
        if (result.OrderId != null) return Ok(new { orderId = result.OrderId, receiptUrl = $"/orders/tickets/{result.OrderId}", demonstration = true });
        return StatusCode(result.Conflict ? 409 : 400, new { message = result.Error });
    }

    [HttpGet("orders/tickets/{id:guid}")]
    public async Task<IActionResult> Tickets(Guid id)
    {
        var order = await Context.PurchaseOrders.AsNoTracking()
            .Where(o => o.PublicId == id && o.UserId == currentUser.UserId)
            .Select(o => new TicketReceiptViewModel
            {
                PublicId = o.PublicId, MovieName = o.MovieName, HallName = o.HallName,
                StartsAt = o.StartsAt, CreatedAt = o.CreatedAt, Total = o.Total,
                Seats = o.Tickets.OrderBy(t => t.Seat.Row).ThenBy(t => t.Seat.Number)
                    .Select(t => new ReceiptSeat { TicketId = t.Id, Row = t.Seat.Row, Number = t.Seat.Number, Price = t.Price }).ToList()
            }).FirstOrDefaultAsync();
        return order == null ? NotFound() : View(order);
    }
}
