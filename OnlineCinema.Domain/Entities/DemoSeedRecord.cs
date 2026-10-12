namespace OnlineCinema.Domain.Entities;

// Стабильное соответствие демоданных сущности. Сохраняется и после её удаления:
// повторный запуск не восстанавливает намеренно удалённые администратором записи.
public sealed class DemoSeedRecord
{
    public required string Key { get; set; }
    public int EntityId { get; set; }
}
