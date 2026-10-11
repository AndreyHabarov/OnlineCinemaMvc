using Microsoft.AspNetCore.Identity;

namespace OnlineCinema.Domain.Entities;

public class User : IdentityUser<int>
{
    public required string Name { get; set; }
    public required string LastName { get; set; }
    public bool IsMan { get; set; }
}