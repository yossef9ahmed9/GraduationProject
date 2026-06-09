namespace GraduationProject.Contracts.MedicalRecord
{
    public record MedicalRecordEntryResponse(
        int      Id,
        int      PatientId,
        string   AuthorEmail,
        string   AuthorName,
        string   AuthorRole,
        string?  MedicalRecord,
        string?  ChronicDiseases,
        string?  Allergies,
        string?  BloodType,
        DateTime CreatedAt
    );
    // UpdateMedicalRecordRequest is reused from GraduationProject.Contracts.Patients
}
