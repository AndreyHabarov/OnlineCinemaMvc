namespace OnlineCinema.Mvc.Models.ViewModels.Home;

public class HomePosterViewModel
{
    public int Id { get; set; }
    public string CardImagePath { get; set; } = string.Empty;
    public int AgeRating { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateOnly WorldPremiere { get; set; }
}
