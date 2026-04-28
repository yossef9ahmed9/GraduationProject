namespace GraduationProject.Contracts.Authentication
{
    public record AuthResponse
    (
        string Id,
        string FullName,
        string? Email,
        string Token,
        int ExpiresIn,
        string RefreshToken
    );
}