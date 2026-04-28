namespace GraduationProject.Authentication
{
    public interface IJwtProvider
    {
        (string tokken, int expireIn) GenerateToken(ApplicationUser user);

        string GenerateRefreshToken();
    }
}