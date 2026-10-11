namespace OnlineCinema.Mvc.Models.ViewModels.Account;

public class AccountViewModel
{
    public string Name { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public bool IsMan { get; set; }
}
