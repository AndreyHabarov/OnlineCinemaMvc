using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using OnlineCinema.Domain.Entities;

namespace OnlineCinema.Domain;

public class AppDbContext : IdentityDbContext<User, Role, int>
{
    public DbSet<Customer> Customers { get; set; }
    public DbSet<Genre> Genres { get; set; }
    public DbSet<Hall> Halls { get; set; }
    public DbSet<Movie> Movies { get; set; }
    public DbSet<MovieGenre> MovieGenres { get; set; }
    public DbSet<Session> Sessions { get; set; }
    public DbSet<Ticket> Tickets { get; set; }
    public DbSet<Advertising> Advertisings { get; set; }
    public DbSet<Promotion> Promotions { get; set; }
    public DbSet<News> News { get; set; }
    public DbSet<Seat> Seats { get; set; }
    public DbSet<PurchaseOrder> PurchaseOrders { get; set; }

    public AppDbContext(DbContextOptions options) : base(options)
    {
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.Entity<Genre>().Property<string>("NormalizedName")
            .HasComputedColumnSql("lower(btrim(\"Name\"))", stored: true);
        modelBuilder.Entity<Genre>().HasIndex("NormalizedName").IsUnique();
        modelBuilder.Entity<Promotion>().Property<string>("NormalizedName")
            .HasComputedColumnSql("lower(btrim(\"Name\"))", stored: true);
        modelBuilder.Entity<Promotion>().HasIndex("NormalizedName").IsUnique();
        modelBuilder.Entity<MovieGenre>().HasOne(g => g.Genre).WithMany(g => g.MovieGenres)
            .HasForeignKey(g => g.GenreId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<Seat>().HasIndex(s => new { s.HallId, s.Row, s.Number }).IsUnique();
        modelBuilder.Entity<Seat>().ToTable(t => t.HasCheckConstraint("CK_Seats_Position", "\"Row\" > 0 AND \"Number\" > 0 AND \"Price\" >= 0"));
        modelBuilder.Entity<Ticket>().HasIndex(t => new { t.SessionId, t.SeatId }).IsUnique()
            .HasFilter("\"Status\" IN (0, 1)");
        modelBuilder.Entity<Ticket>().HasOne(t => t.PurchaseOrder).WithMany(o => o.Tickets)
            .HasForeignKey(t => t.PurchaseOrderId).OnDelete(DeleteBehavior.Cascade);
        modelBuilder.Entity<PurchaseOrder>().HasIndex(o => o.PublicId).IsUnique();
        modelBuilder.Entity<PurchaseOrder>().HasIndex(o => new { o.UserId, o.RequestId }).IsUnique();
        modelBuilder.Entity<PurchaseOrder>().HasOne(o => o.User).WithMany()
            .HasForeignKey(o => o.UserId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<PurchaseOrder>().HasOne(o => o.Session).WithMany()
            .HasForeignKey(o => o.SessionId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<PurchaseOrder>().ToTable(t => t.HasCheckConstraint("CK_PurchaseOrders_Total", "\"Total\" > 0"));
    }

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        base.ConfigureConventions(configurationBuilder);

        configurationBuilder.Properties<DateTime>().HaveColumnType("timestamp without time zone");
        configurationBuilder.Properties<DateTime?>().HaveColumnType("timestamp with time zone");
    }
}
