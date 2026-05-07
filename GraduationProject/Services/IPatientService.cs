using GraduationProject.Entities;

namespace GraduationProject.Services
{
    public interface IPatientService
    {
        Task<IEnumerable<PatientResponse>> GetAllPatientsAsync(CancellationToken cancellationToken = default); 
        Task<Result<PatientResponse?>> GetPatientAsync(int id, CancellationToken cancellationToken = default);
        Task<Result<PatientResponse>> AddPatientAsync(PatientRequest patient, CancellationToken cancellationToken = default);
        Task<Result> UpdatePatientAsync(int id, PatientRequest patient, CancellationToken cancellationToken = default);
        Task<Result> DeletePatientAsync(int id, CancellationToken cancellationToken = default);
    }
}
