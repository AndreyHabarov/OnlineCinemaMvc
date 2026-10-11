using OnlineCinema.Domain.Common;

namespace OnlineCinema.Domain.Entities;

public class Advertising : Entity
{
    public required string PathToImage { get; set; }
}
