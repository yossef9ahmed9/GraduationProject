using GraduationProject.Contracts.PatientProgress;

namespace GraduationProject.Services
{
    public interface IPatientProgressService
    {
        Task<Result<PatientProgressResponse>> GetProgressAsync(
            int patientId,
            string callerEmail,
            string callerRole,
            CancellationToken cancellationToken = default);
    }
}
