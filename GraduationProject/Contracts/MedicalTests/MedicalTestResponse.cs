namespace GraduationProject.Contracts.MedicalTests
{
    public record MedicalTestResponse(
        int Id,
        string Name,
        string Result,
        DateTime Date,
        int PatientId,
        int LabId
    );
}
