using OnlineCinema.Domain.Common;

namespace OnlineCinema.Domain.Entities;

public class Movie : Entity
{                                                   
    public required string Name { get; set; }
    public required string OriginalName { get; set; }
    public ICollection<MovieGenre> MovieGenres { get; set; } = [];
    public int Duration { get; set; }
    public int AgeRating { get; set; }
    public required string Description { get; set; }
    public required string Director { get; set; }
    public required string Actor { get; set; }
    public required string Country { get; set; }
    public DateOnly PremiereDate { get; set; }
    public DateOnly WorldPremiere { get; set; }
    public required string PosterPath { get; set; }
    public float Rating { get; set; }
    public bool IsVisible { get; set; }
    public required string CardImagePath { get; set; }
}