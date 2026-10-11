using OnlineCinema.Domain;
using OnlineCinema.Domain.Common;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;

namespace OnlineCinema.Mvc.Services.CurrentUser;

public class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly AppDbContext _context;

    public CurrentUserService(IHttpContextAccessor httpContextAccessor, AppDbContext context)
    {
        _httpContextAccessor = httpContextAccessor;
        _context = context;
    }

    public int? UserId
    {
        get
        {
            var userId = _httpContextAccessor.HttpContext?.User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? null;
            return int.TryParse(userId, out var id) ? id : null;
        }
    }

    private Task<string?>? _name;

    public Task<string?> GetNameAsync()
    {
        var userId = UserId;
        return _name ??= !IsAuthenticated || userId == null
            ? Task.FromResult<string?>(null)
            : _context.Users.AsNoTracking().Where(u => u.Id == userId.Value)
                .Select(u => (string?)u.Name).FirstOrDefaultAsync();
    }

    public bool IsAuthenticated => _httpContextAccessor.HttpContext?.User?.Identity?.IsAuthenticated ?? false;

    public IReadOnlyList<string> Roles => _httpContextAccessor.HttpContext?.User?
        .FindAll(ClaimTypes.Role)
        ?.Select(r => r.Value)
        ?.ToList() ?? new List<string>();

    public bool IsAdmin => IsAuthenticated && Roles.Any(r => string.Equals(r, StaticRoleNames.ADMIN, StringComparison.Ordinal));
}
