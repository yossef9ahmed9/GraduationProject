using GraduationProject.Contracts.MedicalTests;

namespace GraduationProject.Services
{
    public interface IMedicalTestService
    {
        Task<IEnumerable<MedicalTestResponse>> GetAllAsync(CancellationToken cancellationToken = default);
        Task<Result<MedicalTestResponse>> GetAsync(int id, CancellationToken cancellationToken = default);
        Task<IEnumerable<MedicalTestResponse>> GetByPatientAsync(int patientId, CancellationToken cancellationToken = default);
        Task<IEnumerable<MedicalTestResponse>> GetByLabAsync(int labId, CancellationToken cancellationToken = default);
        Task<Result<MedicalTestResponse>> AddAsync(MedicalTestRequest request, CancellationToken cancellationToken = default);
        Task<Result> UpdateAsync(int id, MedicalTestRequest request, CancellationToken cancellationToken = default);
        Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default);
    }
}
