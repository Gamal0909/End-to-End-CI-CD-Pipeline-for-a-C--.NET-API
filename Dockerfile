FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /src

COPY DevOpsApi/DevOpsApi.csproj .
RUN dotnet restore DevOpsApi.csproj

COPY . .

RUN dotnet publish DevOpsApi/DevOpsApi.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final

WORKDIR /app

COPY --from=build /app/publish .

ENTRYPOINT ["dotnet", "DevOpsApi.dll"]
