using OnlineCinema.Domain.Common;

namespace OnlineCinema.Domain.Entities;

public class Hall : Entity
{
    public required string Name { get; set; }
    public required string PicturePath { get; set; }
    public required string Description { get; set; }
}