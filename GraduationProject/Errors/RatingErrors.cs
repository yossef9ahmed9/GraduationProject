namespace GraduationProject.Errors;

public static class RatingErrors
{
    public static readonly Error InvalidTarget =
        new("Rating.InvalidTarget",
            "Provide exactly one of DoctorId or LabId.",
            StatusCodes.Status400BadRequest);

    public static readonly Error InvalidStars =
        new("Rating.InvalidStars",
            "Stars must be between 1 and 5.",
            StatusCodes.Status400BadRequest);

    public static readonly Error PatientNotFound =
        new("Rating.PatientNotFound",
            "Could not find a patient record for the current user.",
            StatusCodes.Status404NotFound);
}
