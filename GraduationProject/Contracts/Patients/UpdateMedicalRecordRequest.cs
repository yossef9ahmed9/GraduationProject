namespace GraduationProject.Contracts.Patients
{
    public record UpdateMedicalRecordRequest(
        string? MedicalRecord,
        string? ChronicDiseases,
        string? Allergies,
        string? BloodType);
}
