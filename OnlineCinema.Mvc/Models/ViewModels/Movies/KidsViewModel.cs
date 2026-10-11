namespace OnlineCinema.Mvc.Models.ViewModels.Movies
{
    public class KidsViewModel
    {
        public int Id { get; set; }
        public string CardImagePath { get; set; } = string.Empty;
        public int AgeRating { get; set; }
        public string Name { get; set; } = string.Empty;
    }
}
