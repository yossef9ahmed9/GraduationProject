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

        // NEW: forgot password - returns a reset token
        Task<Result<string>> ForgotPasswordAsync(string email);

        // NEW: reset password using the token from forgot password
        Task<Result> ResetPasswordAsync(ResetPasswordRequest request);
    }
}