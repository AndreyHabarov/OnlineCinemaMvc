FROM mcr.microsoft.com/dotnet/sdk:8.0-bookworm-slim AS build
WORKDIR /src
COPY OnlineCinema.Domain/OnlineCinema.Domain.csproj OnlineCinema.Domain/
COPY OnlineCinema.Application/OnlineCinema.Application.csproj OnlineCinema.Application/
COPY OnlineCinema.Mvc/OnlineCinema.Mvc.csproj OnlineCinema.Mvc/
RUN dotnet restore OnlineCinema.Mvc/OnlineCinema.Mvc.csproj
COPY OnlineCinema.Domain/ OnlineCinema.Domain/
COPY OnlineCinema.Application/ OnlineCinema.Application/
COPY OnlineCinema.Mvc/ OnlineCinema.Mvc/
RUN dotnet publish OnlineCinema.Mvc/OnlineCinema.Mvc.csproj -c Release --no-restore -o /out -warnaserror

FROM mcr.microsoft.com/dotnet/aspnet:8.0-bookworm-slim AS runtime
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /out/ ./
COPY data/ ./data/
RUN mkdir -p /app/keys /app/wwwroot/images/promotion/uploads \
    && chown -R app:app /app/keys /app/wwwroot/images/promotion/uploads
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DataProtection__KeysPath=/app/keys
EXPOSE 8080
USER app
ENTRYPOINT ["dotnet", "OnlineCinema.Mvc.dll"]
