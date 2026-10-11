using OnlineCinema.Domain.Common;

namespace OnlineCinema.Domain.Entities;

public class Customer : Entity
{
    public required string Email { get; set; }
}
