namespace OnlineCinema.Mvc.Models.ViewModels.Home;

public class HomeViewModel
{
    public IEnumerable<string> Advertisings { get; set; } = [];
    public IEnumerable<HomePosterViewModel> Posters { get; set; } = [];
    public IEnumerable<HomePromotionViewModel> Promotions { get; set; } = [];
    public IEnumerable<HomeNewsViewModel> News { get; set; } = [];
    public IEnumerable<HomePosterViewModel> FeaturedPosters { get; set; } = [];
    public IReadOnlyList<CatalogGenreViewModel> Genres { get; set; } = [];
    public string Search { get; set; } = string.Empty;
    public int? GenreId { get; set; }
    public int Page { get; set; } = 1;
    public int PageCount { get; set; } = 1;
    public int TotalCount { get; set; }
}

public sealed record CatalogGenreViewModel(int Id, string Name);
