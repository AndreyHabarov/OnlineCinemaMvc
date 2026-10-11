namespace OnlineCinema.Mvc.Models.ViewModels.Home;

public class HomePosterViewModel
{
    public int Id { get; set; }
    public string CardImagePath { get; set; }
    public int AgeRating { get; set; }
    public string Name { get; set; }
    public DateOnly WorldPremiere { get; set; }
}
