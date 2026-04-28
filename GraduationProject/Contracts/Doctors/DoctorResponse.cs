namespace GraduationProject.Contracts.Doctors
{
    public record DoctorResponse(
        int Id,
        string Name,
        string Phone,
        string Email,
        string Specialization
    );
}