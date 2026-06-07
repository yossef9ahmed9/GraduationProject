namespace GraduationProject.Contracts.Authentication
{
    /// <summary>
    /// Wrapper DTO for profile picture upload.
    /// Required so Swashbuckle can correctly reflect the [FromForm] IFormFile parameter.
    /// </summary>
    public class ProfilePictureUploadRequest
    {
        public IFormFile File { get; set; } = null!;
    }
}
