namespace GraduationProject.Errors;

public static class UserErrors
{
    public static readonly Error InvalidCredentials =
        new("User.InvalidCredentials", "Invalid email/password", StatusCodes.Status401Unauthorized);

    public static readonly Error InvalidJwtToken =
        new("User.InvalidJwtToken", "Invalid Jwt token", StatusCodes.Status401Unauthorized);

    public static readonly Error InvalidRefreshToken =
        new("User.InvalidRefreshToken", "Invalid refresh token", StatusCodes.Status401Unauthorized);

    public static readonly Error RegistrationFailed =
        new("User.RegistrationFailed", "Registration failed", StatusCodes.Status400BadRequest);

    // NEW: error for when email is not found during forgot password
    public static readonly Error EmailNotFound =
        new("User.EmailNotFound", "No account found with this email", StatusCodes.Status404NotFound);

    // NEW: error for when the reset token is invalid or expired
    public static readonly Error InvalidResetToken =
        new("User.InvalidResetToken", "Invalid or expired reset token", StatusCodes.Status400BadRequest);
}