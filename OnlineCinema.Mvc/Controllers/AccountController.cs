using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain;
using OnlineCinema.Domain.Entities;
using OnlineCinema.Mvc.Models.ViewModels.Home;
using OnlineCinema.Mvc.Services;
using OnlineCinema.Mvc.Services.CurrentUser;
using OnlineCinema.Mvc.Models.ViewModels.Account;
using OnlineCinema.Mvc.Models.ViewModels.Orders;
using Npgsql;

namespace OnlineCinema.Mvc.Controllers;

public class AccountController : BaseMvcController
{
    private readonly SignInManager<User> _signInManager;
    private readonly UserManager<User> _userManager;
    private readonly ICurrentUserService _currentUserService;

    public AccountController(AppDbContext context, SignInManager<User> signInManager,
        UserManager<User> userManager, ICurrentUserService currentUserService) : base(context)
    {
        _signInManager = signInManager;
        _userManager = userManager;
        _currentUserService = currentUserService;
    }

    [HttpGet]
    public IActionResult Login(string? returnUrl) => RedirectToAction("Index", "Home", new
    {
        login = true,
        returnUrl = Url.IsLocalUrl(returnUrl) ? returnUrl : "/lk"
    });

    [HttpPost]
    public async Task<IActionResult> Login([FromBody] LoginViewModel input)
    {
        if (!ModelState.IsValid) return InvalidInput();
        User? user;
        if (!string.IsNullOrWhiteSpace(input.Email))
        {
            user = await _userManager.FindByEmailAsync(input.Email.Trim());
        }
        else
        {
            var phone = PhoneNumbers.Normalize(input.Phone);
            if (phone == null) return InvalidCredentials();
            var matches = await FindByPhone(phone).Take(2).ToListAsync();
            user = matches.Count == 1 ? matches[0] : null;
        }
        if (user == null) return InvalidCredentials();
        var result = await _signInManager.PasswordSignInAsync(user, input.Password,
            input.RememberMe, lockoutOnFailure: true);
        return result.Succeeded ? Ok(new { user.Name }) : InvalidCredentials();
    }

    [Authorize]
    [HttpPost]
    public async Task<IActionResult> LogOut()
    {
        await _signInManager.SignOutAsync();
        return RedirectToAction("Index", "Home");
    }

    [HttpPost]
    public async Task<IActionResult> Register([FromBody] RegisterViewModel input)
    {
        if (!ModelState.IsValid) return InvalidInput();
        var phone = PhoneNumbers.Normalize(input.PhoneNumber);
        if (phone == null) return BadRequest(new { message = "Укажите российский телефон: +7 и 10 цифр номера." });
        if (await FindByPhone(phone).AnyAsync())
            return BadRequest(new { message = "Пользователь с таким телефоном уже зарегистрирован." });
        var user = new User
        {
            Name = input.Name.Trim(), LastName = input.LastName.Trim(),
            Email = input.Email.Trim(), UserName = input.Email.Trim(),
            PhoneNumber = phone, IsMan = input.IsMan ?? false
        };
        IdentityResult result;
        try
        {
            result = await _userManager.CreateAsync(user, input.Password);
        }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException
            { SqlState: "23505", ConstraintName: "IX_AspNetUsers_NormalizedPhoneNumber" })
        {
            return BadRequest(new { message = "Пользователь с таким телефоном уже зарегистрирован." });
        }
        if (result.Succeeded) return Ok(new { message = "Регистрация завершена. Теперь войдите в аккаунт." });
        var messages = result.Errors.Select(error => error.Code switch
        {
            "DuplicateEmail" or "DuplicateUserName" => "Пользователь с таким email уже зарегистрирован.",
            "InvalidEmail" or "InvalidUserName" => "Укажите корректный email.",
            "PasswordTooShort" or "PasswordRequiresDigit" or "PasswordRequiresUpper" or "PasswordRequiresLower" => "Пароль должен содержать минимум 8 символов, заглавные и строчные латинские буквы и цифры.",
            _ => "Не удалось зарегистрироваться. Проверьте введённые данные."
        }).Distinct().ToArray();
        return BadRequest(new { message = string.Join(" ", messages), errors = messages });
    }

    private IQueryable<User> FindByPhone(string phone)
    {
        return _userManager.Users.Where(user => EF.Property<string?>(user, "NormalizedPhoneNumber") == phone);
    }

    private IActionResult InvalidCredentials() => Unauthorized(new { message = "Неверный email/телефон или пароль. Если было несколько неудачных попыток, повторите вход через 15 минут." });

    private IActionResult InvalidInput() => BadRequest(new
    {
        message = "Проверьте введённые данные.",
        errors = ModelState.Values.SelectMany(value => value.Errors)
            .Select(error => error.ErrorMessage.Any(c => c is >= 'А' and <= 'я' or 'Ё' or 'ё')
                ? error.ErrorMessage : "Некорректные данные запроса.").ToArray()
    });

    [Authorize]
    [Route("lk")]
    public async Task<IActionResult> PersonalAccount()
    {
        var user = await Context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == _currentUserService.UserId);
        if (user == null)
        {
            await _signInManager.SignOutAsync();
            return RedirectToAction("Login", new { returnUrl = "/lk" });
        }
        var orders = await Context.PurchaseOrders.AsNoTracking().Where(o => o.UserId == user.Id)
            .OrderByDescending(o => o.CreatedAt).ThenByDescending(o => o.Id).Take(50)
            .Select(o => new TicketReceiptViewModel
            {
                PublicId = o.PublicId, MovieName = o.MovieName, HallName = o.HallName,
                StartsAt = o.StartsAt, CreatedAt = o.CreatedAt, Total = o.Total,
                Seats = o.Tickets.OrderBy(t => t.Seat.Row).ThenBy(t => t.Seat.Number)
                    .Select(t => new ReceiptSeat { TicketId = t.Id, Row = t.Seat.Row, Number = t.Seat.Number, Price = t.Price }).ToList()
            }).ToListAsync();
        return View("PersonalAccount", new AccountDashboardViewModel { Name = user.Name, Orders = orders });
    }
}
