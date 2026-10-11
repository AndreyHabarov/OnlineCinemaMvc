using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace OnlineCinema.Mvc.Filters;

public sealed class AntiforgeryErrorFilter : IAlwaysRunResultFilter
{
    public void OnResultExecuting(ResultExecutingContext context)
    {
        if (context.Result is AntiforgeryValidationFailedResult)
        {
            context.Result = new BadRequestObjectResult(new
            {
                message = "Проверка безопасности не пройдена. Обновите страницу и повторите действие."
            });
        }
    }

    public void OnResultExecuted(ResultExecutedContext context) { }
}
