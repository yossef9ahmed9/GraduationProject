namespace GraduationProject.Authentication
{
    public interface IJwtProvider
    {
        // UPDATED: added IList<string> roles parameter
        (string token, int expireIn) GenerateToken(ApplicationUser user, IList<string> roles);

        string GenerateRefreshToken();
    }
}