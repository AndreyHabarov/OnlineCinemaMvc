using OnlineCinema.Mvc.Models.ViewModels.Hall;

namespace OnlineCinema.Mvc.Models.ViewModels.Movies
{
    public class MovieViewModel
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string OriginalName { get; set; } = string.Empty;
        public List<string> Genres { get; set; } = [];
        public int Duration { get; set; }
        public int AgeRating { get; set; }
        public string Description { get; set; } = string.Empty;
        public string Director { get; set; } = string.Empty;
        public string Actor { get; set; } = string.Empty;
        public string Country { get; set; } = string.Empty;
        public DateOnly PremiereDate { get; set; }
        public DateOnly WorldPremiere { get; set; }
        public string PosterPath { get; set; } = string.Empty;
        public float Rating { get; set; }
        public bool IsVisible { get; set; }
        public string CardImagePath { get; set; } = string.Empty;

        public DateTime[] SessionDates { get; set; } = [];
        public bool IsDemoCalendar { get; set; }
        public string DemoCalendarLabel { get; set; } = string.Empty;
        public IEnumerable<HallViewModel> Halls { get; set; } = [];
    }
}
