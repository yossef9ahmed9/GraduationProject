using System.Security.Cryptography;

namespace GraduationProject.Authentication
{
    // UPDATED: now reads JWT settings from JwtOptions (appsettings.json)
    // instead of having the key, issuer, audience, and expiry hardcoded here
    // JwtOptions is injected via IOptions<JwtOptions> — registered in DependencyInjection.cs
    public class JwtProvider(IOptions<JwtOptions> options) : IJwtProvider
    {
        private readonly JwtOptions _options = options.Value;

        // UPDATED: added IList<string> roles parameter
        public (string token, int expireIn) GenerateToken(ApplicationUser user, IList<string> roles)
        {
            // base claims (same as before)
            var claims = new List<Claim>
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id),
                new Claim(JwtRegisteredClaimNames.Email, user.Email!),
                new Claim(JwtRegisteredClaimNames.Name, user.FullName),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            // NEW: add each role as a claim so [Authorize(Roles="...")] works
            foreach (var role in roles)
                claims.Add(new Claim(ClaimTypes.Role, role));

            // UPDATED: key now comes from _options.Key instead of being hardcoded
            var symmetricSecurityKey =
                new SymmetricSecurityKey(
                    Encoding.UTF8.GetBytes(_options.Key));

            var signingCredentials =
                new SigningCredentials(
                    symmetricSecurityKey,
                    SecurityAlgorithms.HmacSha256);

            // UPDATED: issuer, audience, and expiry now come from _options
            // changing them in appsettings.json is enough — no code change needed
            var token = new JwtSecurityToken(
                issuer: _options.Issuer,
                audience: _options.Audience,
                claims: claims,
                expires: DateTime.UtcNow.AddMinutes(_options.ExpiryMinutes),
                signingCredentials: signingCredentials
            );

            return (
                token: new JwtSecurityTokenHandler().WriteToken(token),
                expireIn: _options.ExpiryMinutes
            );
        }

        public string GenerateRefreshToken()
        {
            var randomBytes = new byte[64];
            using var rng = RandomNumberGenerator.Create();
            rng.GetBytes(randomBytes);
            return Convert.ToBase64String(randomBytes);
        }
    }
}
