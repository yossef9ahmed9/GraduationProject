namespace GraduationProject.Services
{
    public interface IAuthService
    {
        Task<AuthResponse?> GetTokkenAsync(
            string email,
            string password,
            CancellationToken cancellationToken = default);

        Task<AuthResponse?> RegisterAsync(
            RegisterRequest request,
            CancellationToken cancellationToken = default);

        Task<AuthResponse?> RefreshTokenAsync(string token);
    }
}