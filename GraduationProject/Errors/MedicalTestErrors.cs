namespace GraduationProject.Errors;

public static class MedicalTestErrors
{
    public static readonly Error MedicalTestNotFound =
        new("MedicalTest.NotFound", "No medical test was found with the given ID", StatusCodes.Status404NotFound);

    public static readonly Error PatientNotFound =
        new("MedicalTest.PatientNotFound", "No patient was found with the given ID", StatusCodes.Status404NotFound);

    public static readonly Error LabNotFound =
        new("MedicalTest.LabNotFound", "No lab was found with the given ID", StatusCodes.Status404NotFound);
}
