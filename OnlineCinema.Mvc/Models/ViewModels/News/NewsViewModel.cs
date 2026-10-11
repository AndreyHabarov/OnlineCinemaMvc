namespace OnlineCinema.Mvc.Models.ViewModels.News;

public class NewsViewModel
{
    public int Id { get; set; }
    public string ImagePath { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
}