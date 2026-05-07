

namespace GraduationProject.Errors;

public static class DoctorErors
{
    public static readonly Error DoctorNotFound =
        new("Doctor.NotFound", "No Doctor was found with the given ID", StatusCodes.Status404NotFound);

    public static readonly Error DuplicatedDoctor =
        new("Doctor.Duplicated", "Another doctor with the same information is already exists", StatusCodes.Status409Conflict);
}