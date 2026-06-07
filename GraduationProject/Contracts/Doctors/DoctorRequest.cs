namespace GraduationProject.Contracts.Doctors
{
    public record DoctorRequest(
        string Name,
        string Phone,
        string Email,
        string Specialization,
        string? ClinicName    = null,
        string? ClinicAddress = null,
        double? ClinicLatitude  = null,
        double? ClinicLongitude = null
    );
}