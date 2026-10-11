namespace OnlineCinema.Mvc.Models.ViewModels.Home;

public class HomeViewModel
{
    public IEnumerable<string> Advertisings { get; set; } = [];
    public IEnumerable<HomePosterViewModel> Posters { get; set; } = [];
    public IEnumerable<HomePromotionViewModel> Promotions { get; set; } = [];
    public IEnumerable<HomeNewsViewModel> News { get; set; } = [];
    public IEnumerable<LoginViewModel> Logins { get; set; } = [];
}
