namespace OnlineCinema.Mvc.Models.Dto.Common;

public class PagedRequestDto
{
    [System.ComponentModel.DataAnnotations.Range(0, 100000)]
    public int SkipCount { get; set; }
    [System.ComponentModel.DataAnnotations.Range(1, 100)]
    public int PageSize { get; set; } = 10;
}
