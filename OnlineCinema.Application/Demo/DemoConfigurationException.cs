namespace OnlineCinema.Application.Demo;

// Сообщения этого типа заранее написаны приложением и не содержат секретов.
public sealed class DemoConfigurationException(string message) : Exception(message);
