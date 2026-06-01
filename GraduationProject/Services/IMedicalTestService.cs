using GraduationProject.Contracts.MedicalTests;

namespace GraduationProject.Services
{
    public interface IMedicalTestService
    {
        Task<PagedResponse<MedicalTestResponse>> GetAllAsync(int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);
        Task<Result<MedicalTestResponse>> GetAsync(int id, CancellationToken cancellationToken = default);
        Task<PagedResponse<MedicalTestResponse>> GetByPatientAsync(int patientId, int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);
        Task<PagedResponse<MedicalTestResponse>> GetByLabAsync(int labId, int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);
        Task<Result<MedicalTestResponse>> AddAsync(MedicalTestRequest request, CancellationToken cancellationToken = default);
        Task<Result> UpdateAsync(int id, MedicalTestRequest request, CancellationToken cancellationToken = default);
        Task<Result> UpdateImagePathAsync(int id, string imagePath, CancellationToken cancellationToken = default);
        Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default);
    }
}
