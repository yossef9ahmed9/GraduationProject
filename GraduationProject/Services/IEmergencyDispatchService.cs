using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Services
{
    // NEW FILE: interface for the emergency dispatch service
    // the entity and DbSet existed but no service was wired up — feature was completely dead
    public interface IEmergencyDispatchService
    {
        Task<PagedResponse<EmergencyDispatchResponse>> GetAllAsync(int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);

        Task<PagedResponse<EmergencyDispatchResponse>> GetByPatientAsync(int patientId, int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);

        Task<PagedResponse<EmergencyDispatchResponse>> GetByAmbulanceAsync(int ambulanceId, int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);

        // create a new dispatch when an emergency is triggered
        Task<Result<EmergencyDispatchResponse>> AddAsync(EmergencyDispatchRequest request, CancellationToken cancellationToken = default);

        // update status as the dispatch progresses: Pending → OnTheWay → Arrived → Resolved
        // also auto-stamps ArrivedAt and ResolvedAt timestamps when those statuses are set
        Task<Result> UpdateStatusAsync(int id, string status, CancellationToken cancellationToken = default);
    }
}
