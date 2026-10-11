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
    }

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        base.ConfigureConventions(configurationBuilder);

        configurationBuilder.Properties<DateTime>().HaveColumnType("timestamp without time zone");
        configurationBuilder.Properties<DateTime?>().HaveColumnType("timestamp with time zone");
    }
}
