using OnlineCinema.Domain.Common;

namespace OnlineCinema.Domain.Entities;

public class News : Entity
{
    public required string ImagePath { get; set; }
    public required string Name { get; set; }
    public DateTime Date { get; set; }
    public required string Description { get; set; }
}
