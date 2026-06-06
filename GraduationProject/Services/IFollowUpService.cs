using GraduationProject.Contracts.FollowUps;

namespace GraduationProject.Services
{
    public interface IFollowUpService
    {
        Task<PagedResponse<FollowUpResponse>> GetAllAsync(FollowUpFilter filter, CancellationToken cancellationToken = default);
        Task<Result<FollowUpResponse>> GetAsync(int id, CancellationToken cancellationToken = default);
        Task<PagedResponse<FollowUpResponse>> GetByPatientAsync(int patientId, int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);
        Task<PagedResponse<FollowUpResponse>> GetByDoctorAsync(int doctorId, int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);
        Task<Result<FollowUpResponse>> AddAsync(FollowUpRequest request, CancellationToken cancellationToken = default);
        Task<Result> UpdateAsync(int id, FollowUpRequest request, CancellationToken cancellationToken = default);
        Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default);
    }
}
