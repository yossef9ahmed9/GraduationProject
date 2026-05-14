namespace GraduationProject.Contracts.Patients
{
   public  record PatientResponse
    (
     int Id ,
     string Name, 
     string Gender, 
     string Phone ,
     string Email ,
     string Address, 
     DateOnly BirthDate ,
     string MedicalRecord,

     // UPDATED: added fields that exist on the Patient entity but were missing from the response
     // frontend was getting incomplete data — BloodType, ChronicDiseases, Allergies, IsInEmergency
     // were all being silently dropped
     string BloodType,
     string? ChronicDiseases,
     string? Allergies,
     bool IsInEmergency
);
}
