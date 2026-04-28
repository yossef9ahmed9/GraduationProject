namespace GraduationProject.Contracts.Relatives
{
    public record RelativeRequest(
        string Name,
        string Phone,
        string RelationType,
        int PatientId
    );
}