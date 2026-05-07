

namespace GraduationProject.Errors;

public static class PatientErrors
{
    public static readonly Error PatientNotFound =
        new("Patient.NotFound", "No Patient was found with the given ID", StatusCodes.Status404NotFound);

    public static readonly Error DuplicatedPatient =
        new("Patient.Duplicated", "Another patient with the same Email is already exists", StatusCodes.Status409Conflict);
}