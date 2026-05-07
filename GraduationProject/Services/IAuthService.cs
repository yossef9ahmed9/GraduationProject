namespace GraduationProject.Services
{
    public interface IAuthService
    {
        Task<Result<AuthResponse?>> GetTokkenAsync(
            string email,
            string password,
            CancellationToken cancellationToken = default);

        Task<Result<AuthResponse?>> RegisterAsync(
            RegisterRequest request,
            CancellationToken cancellationToken = default);

        Task<Result<AuthResponse?>> RefreshTokenAsync(string token);
    }
}