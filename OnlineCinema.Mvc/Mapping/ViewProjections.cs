using System.Linq.Expressions;
using OnlineCinema.Domain.Entities;
using OnlineCinema.Mvc.Models.Dto.Promotions;
using OnlineCinema.Mvc.Models.ViewModels.Hall;
using OnlineCinema.Mvc.Models.ViewModels.Home;
using OnlineCinema.Mvc.Models.ViewModels.Movies;
using OnlineCinema.Mvc.Models.ViewModels.News;
using OnlineCinema.Mvc.Models.ViewModels.Promotions;

namespace OnlineCinema.Mvc.Mapping;

// Expression-проекции выполняются в SQL и явно перечисляют поля ответа.
public static class ViewProjections
{
    public static readonly Expression<Func<Movie, HomePosterViewModel>> HomePoster = m => new()
    {
        Id = m.Id, Name = m.Name, CardImagePath = m.CardImagePath,
        AgeRating = m.AgeRating, WorldPremiere = m.WorldPremiere
    };
    public static readonly Expression<Func<Movie, KidsViewModel>> Kids = m => new()
    {
        Id = m.Id, Name = m.Name, CardImagePath = m.CardImagePath, AgeRating = m.AgeRating
    };
    public static readonly Expression<Func<Movie, ArtViewModel>> Art = m => new()
    {
        Id = m.Id, Name = m.Name, CardImagePath = m.CardImagePath, AgeRating = m.AgeRating
    };
    public static readonly Expression<Func<Movie, MovieViewModel>> MovieDetails = m => new()
    {
        Id = m.Id, Name = m.Name, OriginalName = m.OriginalName,
        Genres = m.MovieGenres.OrderBy(mg => mg.Genre.Name).Select(mg => mg.Genre.Name).ToList(),
        Duration = m.Duration, AgeRating = m.AgeRating, Description = m.Description,
        Director = m.Director, Actor = m.Actor, Country = m.Country,
        PremiereDate = m.PremiereDate, WorldPremiere = m.WorldPremiere,
        PosterPath = m.PosterPath, Rating = m.Rating, IsVisible = m.IsVisible,
        CardImagePath = m.CardImagePath, SessionDates = Array.Empty<DateTime>(), Halls = Array.Empty<HallViewModel>()
    };
    public static readonly Expression<Func<Hall, HallViewModel>> Hall = h => new()
    {
        Id = h.Id, Name = h.Name, PicturePath = h.PicturePath, Description = h.Description
    };
    public static readonly Expression<Func<News, NewsViewModel>> NewsDetails = n => new()
    {
        Id = n.Id, Name = n.Name, ImagePath = n.ImagePath, Date = n.Date, Description = n.Description
    };
    public static readonly Expression<Func<News, HomeNewsViewModel>> HomeNews = n => new()
    {
        Id = n.Id, Name = n.Name, ImagePath = n.ImagePath, Date = n.Date
    };
    public static readonly Expression<Func<Promotion, PromotionViewModel>> PromotionDetails = p => new()
    {
        Id = p.Id, Name = p.Name, DisplayName = p.DisplayName, Description = p.Description,
        DateTime = p.DateTime, ImagePath = p.ImagePath, ButtonText = p.ButtonText, Link = p.Link
    };
    public static readonly Expression<Func<Promotion, HomePromotionViewModel>> HomePromotion = p => new()
    {
        Id = p.Id, Name = p.Name, DisplayName = p.DisplayName, Description = p.Description,
        ImagePath = p.ImagePath, ButtonText = p.ButtonText, Link = p.Link
    };
    public static readonly Expression<Func<Promotion, PromotionDto>> PromotionDto = p => new()
    {
        Id = p.Id, Name = p.Name, DisplayName = p.DisplayName, Description = p.Description,
        DateTime = p.DateTime, ImagePath = p.ImagePath, ButtonText = p.ButtonText, Link = p.Link
    };
}
