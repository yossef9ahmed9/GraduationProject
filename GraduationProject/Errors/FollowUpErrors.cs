namespace GraduationProject.Errors;

public static class FollowUpErrors
{
    public static readonly Error PatientNotFound =
        new("FollowUp.PatientNotFound", "No patient was found with the given ID", StatusCodes.Status404NotFound);

    public static readonly Error DoctorNotFound =
        new("FollowUp.DoctorNotFound", "No doctor was found with the given ID", StatusCodes.Status404NotFound);

    public static readonly Error FollowUpNotFound =
        new("FollowUp.NotFound", "No follow-up was found with the given ID", StatusCodes.Status404NotFound);
}
