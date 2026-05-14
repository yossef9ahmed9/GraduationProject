namespace GraduationProject.Contracts.Patients
{
    public record PatientRequest(
        string Name,
        string Gender,
        string Phone,
        string Email,
        string Address,
        DateOnly BirthDate,
        string MedicalRecord,
        string? BloodType = null,
        string? ChronicDiseases = null,
        string? Allergies = null
    );
}
