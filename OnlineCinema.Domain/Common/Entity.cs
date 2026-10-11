namespace OnlineCinema.Domain.Common;

public abstract class Entity<TPrimaryKey> where TPrimaryKey : struct
{
    public TPrimaryKey Id { get; set; }
}
public abstract class Entity : Entity<int>
{
}
