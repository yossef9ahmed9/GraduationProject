using GraduationProject.Contracts.FollowUps;

namespace GraduationProject.Services
{
    public interface IFollowUpService
    {
        Task<IEnumerable<FollowUpResponse>> GetAllAsync(CancellationToken cancellationToken = default);
        Task<Result<FollowUpResponse>> GetAsync(int id, CancellationToken cancellationToken = default);
        Task<IEnumerable<FollowUpResponse>> GetByPatientAsync(int patientId, CancellationToken cancellationToken = default);
        Task<IEnumerable<FollowUpResponse>> GetByDoctorAsync(int doctorId, CancellationToken cancellationToken = default);
        Task<Result<FollowUpResponse>> AddAsync(FollowUpRequest request, CancellationToken cancellationToken = default);
        Task<Result> UpdateAsync(int id, FollowUpRequest request, CancellationToken cancellationToken = default);
        Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default);
    }
}