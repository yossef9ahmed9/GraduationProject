namespace GraduationProject.Contracts.RelativeRequests
{
    public record RelativeRequestResponse(
        int      Id,
        int      RelativeId,
        string   RelativeName,
        string   RelativePhone,
        string   RelationType,
        int      PatientId,
        string   Status,
        DateTime CreatedAt,
        DateTime? UpdatedAt
    );

    public record RelativeRequestStatusResponse(
        int      Id,
        int      PatientId,
        string   PatientName,
        string   Status,
        DateTime CreatedAt,
        DateTime? UpdatedAt
    );

    public record PatientSearchResult(
        int    Id,
        string Name,
        string Email,
        string Phone,
        string Gender
    );

    public record SendRelativeRequestRequest(int PatientId);
}
