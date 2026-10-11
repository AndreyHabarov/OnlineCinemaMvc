namespace OnlineCinema.Mvc.Models.ViewModels.Home;

public class HomeNewsViewModel
{
    public int Id { get; set; }
    public string ImagePath { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public DateTime Date { get; set; }
}
