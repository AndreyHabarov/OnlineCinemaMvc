namespace OnlineCinema.Mvc.Services;

public static class PhoneNumbers
{
    public static string? Normalize(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Any(c => !char.IsAsciiDigit(c) && !"+ ()-".Contains(c)))
            return null;
        var digits = new string(value.Where(char.IsAsciiDigit).ToArray());
        if (digits.Length == 10) digits = "7" + digits;
        if (digits.Length != 11 || (digits[0] != '7' && digits[0] != '8')) return null;
        return "+7" + digits[1..];
    }
}
