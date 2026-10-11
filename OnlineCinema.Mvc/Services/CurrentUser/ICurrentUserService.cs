namespace OnlineCinema.Mvc.Services.CurrentUser;

public interface ICurrentUserService
{
    int? UserId { get; }
    Task<string?> GetNameAsync();
    bool IsAuthenticated { get; } 
    bool IsAdmin { get; } 
    IReadOnlyList<string> Roles { get; }
}
