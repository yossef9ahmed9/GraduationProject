using GraduationProject.Errors;

namespace GraduationProject.Services
{
    public class AuthService(
        UserManager<ApplicationUser> userManager,
        IJwtProvider jwtProvider,
        AppDbContext context) : IAuthService
    {
        public UserManager<ApplicationUser> _userManager { get; } = userManager;

        public IJwtProvider _JwtProvider = jwtProvider;

        private readonly AppDbContext _context = context;

        public async Task<Result<AuthResponse?>> GetTokkenAsync(
            string email,
            string password,
            CancellationToken cancellationToken = default)
        {
            var user = await _userManager.FindByEmailAsync(email);

            if (user == null)
                return Result.Failure<AuthResponse>(UserErrors.InvalidCredentials);

            var IsVAlidPassword =
                await _userManager.CheckPasswordAsync(user, password);

            if (!IsVAlidPassword)
                return Result.Failure<AuthResponse>(UserErrors.InvalidCredentials);

            var (token, expiresIn) = _JwtProvider.GenerateToken(user);

            var refreshToken = _JwtProvider.GenerateRefreshToken();

            user.RefreshTokens.Add(new RefreshToken
            {
                Token = refreshToken,
                CreatedOn = DateTime.UtcNow,
                ExpiresOn = DateTime.UtcNow.AddDays(7)
            });

            await _userManager.UpdateAsync(user);

            var response= new AuthResponse(
                user.Id,
                user.FullName,
                user.Email,
                token,
                expiresIn * 60,
                refreshToken
            );
            return Result.Success(response);
        }

        public async Task<Result<AuthResponse?>> RegisterAsync(
            RegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            var user = new ApplicationUser
            {
                FullName = request.FullName,
                Email = request.Email,
                UserName = request.Email
            };

            var result =
                await _userManager.CreateAsync(user, request.Password);

            if (!result.Succeeded)
                return Result.Failure<AuthResponse>(UserErrors.RegistrationFailed);

            var (token, expiresIn) =
                _JwtProvider.GenerateToken(user);

            var refreshToken =
                _JwtProvider.GenerateRefreshToken();

            user.RefreshTokens.Add(new RefreshToken
            {
                Token = refreshToken,
                CreatedOn = DateTime.UtcNow,
                ExpiresOn = DateTime.UtcNow.AddDays(7)
            });

            await _userManager.UpdateAsync(user);

            var response= new AuthResponse(
                user.Id,
                user.FullName,
                user.Email,
                token,
                expiresIn * 60,
                refreshToken
            );
            return Result.Success(response);
        }

        public async Task<Result<AuthResponse?>> RefreshTokenAsync(string token)
        {
            var user = _context.Users
                .Include(u => u.RefreshTokens)
                .SingleOrDefault(u =>
                    u.RefreshTokens.Any(t => t.Token == token));

            if (user is null)
                return Result.Failure<AuthResponse>(UserErrors.InvalidRefreshToken);

            var refreshToken =
                user.RefreshTokens.Single(t => t.Token == token);

            if (!refreshToken.IsActive)
                return Result.Failure<AuthResponse>(UserErrors.InvalidRefreshToken);
            refreshToken.RevokedOn = DateTime.UtcNow;

            var newRefreshToken =
                _JwtProvider.GenerateRefreshToken();

            user.RefreshTokens.Add(new RefreshToken
            {
                Token = newRefreshToken,
                CreatedOn = DateTime.UtcNow,
                ExpiresOn = DateTime.UtcNow.AddDays(7)
            });

            var (jwtToken, expiresIn) =
                _JwtProvider.GenerateToken(user);

            await _userManager.UpdateAsync(user);

            var response = new AuthResponse(
                user.Id,
                user.FullName,
                user.Email,
                jwtToken,
                expiresIn * 60,
                newRefreshToken
            );
            return Result.Success(response);
        }
    }
}