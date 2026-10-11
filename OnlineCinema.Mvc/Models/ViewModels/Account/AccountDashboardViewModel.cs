using OnlineCinema.Mvc.Models.ViewModels.Orders;

namespace OnlineCinema.Mvc.Models.ViewModels.Account;

public sealed class AccountDashboardViewModel
{
    public string Name { get; init; } = string.Empty;
    public List<TicketReceiptViewModel> Orders { get; init; } = [];
}
