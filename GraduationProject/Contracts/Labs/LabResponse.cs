namespace GraduationProject.Contracts.Labs
{
    public record LabResponse(
        int Id,
        string Name,
        string Location,
        string Phone,
        string Email,
        double? Latitude  = null,
        double? Longitude = null,
        string? ProfilePictureUrl = null
    );
}
