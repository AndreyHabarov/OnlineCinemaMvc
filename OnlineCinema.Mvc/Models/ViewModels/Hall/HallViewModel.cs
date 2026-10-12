namespace OnlineCinema.Mvc.Models.ViewModels.Hall;

public class HallViewModel
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string PicturePath { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int SeatCount { get; set; }
    public int RowCount { get; set; }
}
