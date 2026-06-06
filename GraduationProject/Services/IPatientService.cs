using GraduationProject.Entities;

namespace GraduationProject.Services
{
    public interface IPatientService
    {
        Task<PagedResponse<PatientResponse>> GetAllPatientsAsync(int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default); 
        Task<Result<PatientResponse?>> GetPatientAsync(int id, CancellationToken cancellationToken = default);
        Task<Result<PatientResponse>> AddPatientAsync(PatientRequest patient, CancellationToken cancellationToken = default);
        Task<Result> UpdatePatientAsync(int id, PatientRequest patient, CancellationToken cancellationToken = default);
        Task<Result> DeletePatientAsync(int id, CancellationToken cancellationToken = default);
        Task<Result> UpdateBloodTypeAsync(int id, string bloodType, CancellationToken cancellationToken = default);
    }
}
