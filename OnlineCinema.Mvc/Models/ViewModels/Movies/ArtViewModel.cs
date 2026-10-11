using OnlineCinema.Domain.Entities;

namespace OnlineCinema.Mvc.Models.ViewModels.Movies
{
    public class ArtViewModel
    {
        public int Id { get; set; }
        public string CardImagePath { get; set; } = string.Empty;
        public int AgeRating { get; set; }
        public string Name { get; set; } = string.Empty;
        public ICollection<MovieGenre> Genres { get; set; } = [];
    }
}
