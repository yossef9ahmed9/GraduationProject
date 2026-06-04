using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Services
{
    public interface IEmergencyDispatchService
    {
        Task<PagedResponse<EmergencyDispatchResponse>> GetAllAsync(
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default);

        Task<PagedResponse<EmergencyDispatchResponse>> GetByPatientAsync(
            int patientId,
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default);

        Task<PagedResponse<EmergencyDispatchResponse>> GetByAmbulanceAsync(
            int ambulanceId,
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default);

        Task<Result<EmergencyDispatchResponse>> AddAsync(
            EmergencyDispatchRequest request,
            CancellationToken cancellationToken = default);

        Task<Result> UpdateStatusAsync(
            int id, string status,
            CancellationToken cancellationToken = default);

        // FIXED: entity had ISoftDeletable but delete was never exposed via the API
        Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default);
    }
}
