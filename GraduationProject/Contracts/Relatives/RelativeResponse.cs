namespace GraduationProject.Contracts.Relatives
{
    public record RelativeResponse(
        int Id,
        string Name,
        string Phone,
        string RelationType,
        int PatientId
    );
}