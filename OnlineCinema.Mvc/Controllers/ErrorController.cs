using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using OnlineCinemaMvc.Models;

namespace OnlineCinema.Mvc.Controllers;

// Не зависит от БД и принимает исходный HTTP-метод при повторном выполнении запроса.
[AllowAnonymous]
public sealed class ErrorController(ILogger<ErrorController> logger) : Controller
{
    [Route("Home/Error")]
    [IgnoreAntiforgeryToken]
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        var requestId = HttpContext.TraceIdentifier;
        var failure = HttpContext.Features.Get<IExceptionHandlerPathFeature>();
        if (failure is not null)
        {
            // Сообщение исключения, URL, тело запроса и cookie могут содержать секреты.
            logger.LogError("Ошибка обработки запроса {RequestId}. Тип: {ExceptionType}",
                requestId, failure.Error.GetType().FullName);
        }

        Response.StatusCode = StatusCodes.Status500InternalServerError;
        return View("~/Views/Shared/Error.cshtml", new ErrorViewModel { RequestId = requestId });
    }
}
