namespace GraduationProject.Services
{
    public class RefreshTokenCleanupService(
        IServiceScopeFactory scopeFactory,
        ILogger<RefreshTokenCleanupService> logger) : BackgroundService
    {
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    using var scope = scopeFactory.CreateScope();
                    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

                    var cutoff = DateTime.UtcNow.AddDays(-30);
                    var expired = await context.Set<RefreshToken>()
                        .Where(t => t.RevokedOn != null || t.ExpiresOn < cutoff)
                        .ExecuteDeleteAsync(stoppingToken);

                    if (expired > 0)
                        logger.LogInformation("Cleaned up {Count} expired/revoked refresh tokens", expired);
                }
                catch (OperationCanceledException)
                {
                    // Server is shutting down — normal, not an error
                    break;
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Error during refresh token cleanup");
                }

                try
                {
                    await Task.Delay(TimeSpan.FromHours(24), stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    // Server is shutting down mid-wait — normal, not an error
                    break;
                }
            }
        }
    }
}
