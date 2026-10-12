using OnlineCinema.Domain.Entities;

namespace OnlineCinema.Application;

// Одна политика для афиши, API, выбора мест и серверной покупки.
public sealed class SessionAvailability(bool isDemo, DateTime[] demoDates)
{
    private readonly DateTime[] dates = demoDates.Select(d => d.Date).Distinct().Order().ToArray();
    public bool IsDemo => isDemo;
    public DateTime[] DemoDates => dates.ToArray();

    public IQueryable<Session> Available(IQueryable<Session> sessions)
    {
        if (IsDemo) return sessions.Where(s => dates.Contains(s.DateStart.Date));
        var now = CinemaTime.Now;
        return sessions.Where(s => s.DateStart > now);
    }

    public bool CanPurchase(DateTime startsAt) => CanPurchase(startsAt, CinemaTime.Now);

    public bool CanPurchase(DateTime startsAt, DateTime now) =>
        IsDemo ? dates.Contains(startsAt.Date) : startsAt > now;
}
