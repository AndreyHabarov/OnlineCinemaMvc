namespace OnlineCinema.Mvc.Models.ViewModels.Promotions;

public class PromotionCardViewModel
{
    public int Id { get; set; }
    public string ImagePath { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string ButtonText { get; set; } = string.Empty;
    public string? Link { get; set; }
}
