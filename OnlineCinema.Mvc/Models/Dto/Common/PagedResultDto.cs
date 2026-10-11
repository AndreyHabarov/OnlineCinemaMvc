namespace OnlineCinema.Mvc.Models.Dto.Common;

public sealed class PagedResultDto<TItems>
{
    public long TotalCount { get; set; }
    public long FilteredCount { get; set; }
    public IReadOnlyList<TItems> Items { get; set; }

    public PagedResultDto(long totalCount, IReadOnlyList<TItems> items, long? filteredCount = null)
    {
        TotalCount = totalCount;
        FilteredCount = filteredCount ?? totalCount;
        Items = items;
    }
}
