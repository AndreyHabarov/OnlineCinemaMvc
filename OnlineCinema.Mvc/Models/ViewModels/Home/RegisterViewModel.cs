using System.ComponentModel.DataAnnotations;

namespace OnlineCinema.Mvc.Models.ViewModels.Home;

public class RegisterViewModel
{
    [Required(ErrorMessage = "Необходимо ввести имя.")]
    [StringLength(60, ErrorMessage = "Имя должно быть не длиннее 60 символов.")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "Необходимо ввести фамилию.")]
    [StringLength(60, ErrorMessage = "Фамилия должна быть не длиннее 60 символов.")]
    public string LastName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Необходимо ввести телефон.")]
    [StringLength(32, ErrorMessage = "Телефон должен быть не длиннее 32 символов.")]
    public string PhoneNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = "Необходимо ввести email.")]
    [EmailAddress(ErrorMessage = "Укажите корректный email.")]
    [StringLength(254, ErrorMessage = "Email должен быть не длиннее 254 символов.")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Необходимо ввести пароль.")]
    [StringLength(128, MinimumLength = 8, ErrorMessage = "Длина пароля — от 8 до 128 символов.")]
    [RegularExpression(@"^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])[\s\S]+$", ErrorMessage = "Пароль должен содержать латинские заглавные и строчные буквы и цифры.")]
    [Compare(nameof(ConfirmPassword), ErrorMessage = "Пароли не совпадают.")]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = "Повторите пароль.")]
    [StringLength(128, ErrorMessage = "Пароль должен быть не длиннее 128 символов.")]
    public string ConfirmPassword { get; set; } = string.Empty;
    public bool? IsMan { get; set; }
}
