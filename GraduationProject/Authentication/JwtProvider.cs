
using System.Security.Cryptography;

namespace GraduationProject.Authentication
{
    public class JwtProvider : IJwtProvider
    {
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

            var symmetricSecurityKey =
                new SymmetricSecurityKey(
                    Encoding.UTF8.GetBytes(
                        "7lxKQWrP1jN54i6/ns6eQp0oNdKSNDOLyuids0kxoVI="));

            var signingCredentials =
                new SigningCredentials(
                    symmetricSecurityKey,
                    SecurityAlgorithms.HmacSha256);

            var expiresin = 30;

            var token = new JwtSecurityToken(
                issuer: "GraduationProjectApp",
                audience: "GraduationProject users",
                claims: claims,
                expires: DateTime.UtcNow.AddMinutes(expiresin),
                signingCredentials: signingCredentials
            );

            return (
                token: new JwtSecurityTokenHandler().WriteToken(token),
                expireIn: expiresin
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