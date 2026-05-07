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
     string MedicalRecord

);


}
