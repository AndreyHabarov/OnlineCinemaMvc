using System.ComponentModel.DataAnnotations;

namespace OnlineCinema.Mvc.Models.ViewModels.Home;

public class LoginViewModel : IValidatableObject
{
    [EmailAddress(ErrorMessage = "Укажите корректный email.")]
    [StringLength(254, ErrorMessage = "Email должен быть не длиннее 254 символов.")]
    public string? Email { get; set; }

    [Required(ErrorMessage = "Необходимо ввести пароль.")]
    [StringLength(128, ErrorMessage = "Пароль должен быть не длиннее 128 символов.")]
    [DataType(DataType.Password)]
    public string Password { get; set; } = string.Empty;

    [StringLength(32, ErrorMessage = "Телефон должен быть не длиннее 32 символов.")]
    public string? Phone { get; set; }
    public bool RememberMe { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (string.IsNullOrWhiteSpace(Email) == string.IsNullOrWhiteSpace(Phone))
            yield return new ValidationResult("Укажите email или телефон для входа.");
    }
}
