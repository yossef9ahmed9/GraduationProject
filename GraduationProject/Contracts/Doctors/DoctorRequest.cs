namespace GraduationProject.Contracts.Doctors
{
    public record DoctorRequest(
        string Name,
        string Phone,
        string Email,
        string Specialization
    );
}