namespace GraduationProject.Contracts.Labs
{
    public record LabRequest(
        string Name,
        string Location,
        string Phone,
        double? Latitude  = null,
        double? Longitude = null
    );
}
