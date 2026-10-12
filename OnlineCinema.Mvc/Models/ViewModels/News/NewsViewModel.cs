namespace OnlineCinema.Mvc.Models.ViewModels.News;

public class NewsViewModel
{
    public int Id { get; set; }
    public string ImagePath { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public string Description { get; set; } = string.Empty;
    public bool IsRetrospective { get; set; }
    public int? MovieId { get; set; }
    public string? MovieName { get; set; }
    public string? SourceTitle { get; set; }
    public string? SourceUrl { get; set; }
}
