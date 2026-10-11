using OnlineCinema.Domain.Common;

namespace OnlineCinema.Domain.Entities;

public class Promotion : Entity
{
    public DateTime DateTime { get; set; }
    public required string ImagePath { get; set; }
    public required string Name { get; set; }
    public required string DisplayName { get; set; }
    public required string Description { get; set; }
    public required string ButtonText { get; set; }
    public string? Link { get; set; }
}