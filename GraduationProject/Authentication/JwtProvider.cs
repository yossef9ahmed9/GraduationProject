
using System.Security.Cryptography;

namespace GraduationProject.Authentication
{
    public class JwtProvider : IJwtProvider
    {
        public (string tokken, int expireIn) GenerateToken(ApplicationUser user)
        {
            Claim[] claims =
            [
                new Claim(JwtRegisteredClaimNames.Sub, user.Id),
                new Claim(JwtRegisteredClaimNames.Email, user.Email!),
                new Claim(JwtRegisteredClaimNames.Name, user.FullName),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            ];

            var symmetricSecurityKey =
                new SymmetricSecurityKey(
                    Encoding.UTF8.GetBytes(
                        "7lxKQWrP1jN54i6/ns6eQp0oNdKSNDOLyuids0kxoVI="));

            var singningCredentials =
                new SigningCredentials(
                    symmetricSecurityKey,
                    SecurityAlgorithms.HmacSha256);

            var expiresin = 30;

            var tokken = new JwtSecurityToken(
                issuer: "GraduationProjectApp",
                audience: "GraduationProject users",
                claims: claims,
                expires: DateTime.UtcNow.AddMinutes(expiresin),
                signingCredentials: singningCredentials
            );

            return (
                tokken: new JwtSecurityTokenHandler().WriteToken(tokken),
                expiresin: expiresin
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