namespace GraduationProject.Errors;

public static class UserErrors
{
    public static readonly Error InvalidCredentials =
        new("User.InvalidCredentials", "Invalid email/password", StatusCodes.Status401Unauthorized);

    public static readonly Error InvalidJwtToken =
        new("User.InvalidJwtToken", "Invalid Jwt token", StatusCodes.Status401Unauthorized);

    public static readonly Error InvalidRefreshToken =
        new("User.InvalidRefreshToken", "Invalid refresh token", StatusCodes.Status401Unauthorized);

    public static Error RegistrationFailed(string details = "Registration failed") =>
        new("User.RegistrationFailed", details, StatusCodes.Status400BadRequest);

    // NEW: error for when email is not found during forgot password
    public static readonly Error EmailNotFound =
        new("User.EmailNotFound", "No account found with this email", StatusCodes.Status404NotFound);

    // NEW: error for when the reset token is invalid or expired
    public static readonly Error InvalidResetToken =
        new("User.InvalidResetToken", "Invalid or expired reset token", StatusCodes.Status400BadRequest);

    public static readonly Error IncorrectCurrentPassword =
        new("User.IncorrectCurrentPassword", "Current password is incorrect.", StatusCodes.Status400BadRequest);

    public static readonly Error PasswordChangeFailed =
        new("User.PasswordChangeFailed", "Failed to change password.", StatusCodes.Status400BadRequest);

    public static readonly Error NameUpdateFailed =
        new("User.NameUpdateFailed", "Failed to update display name.", StatusCodes.Status400BadRequest);

    public static readonly Error ProfilePictureUploadFailed =
        new("User.ProfilePictureUploadFailed", "Failed to upload profile picture.", StatusCodes.Status400BadRequest);

    public static readonly Error InvalidFileType =
        new("User.InvalidFileType", "Only jpg and png files are allowed.", StatusCodes.Status400BadRequest);
}