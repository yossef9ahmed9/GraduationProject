namespace GraduationProject.Contracts.MedicalTests
{
    public record MedicalTestRequest(
        string Name,
        string Result,
        int PatientId,
        int LabId
    );
}