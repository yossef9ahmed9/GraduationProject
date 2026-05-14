using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Services
{
    // NEW FILE: interface for the emergency dispatch service
    // the entity and DbSet existed but no service was wired up — feature was completely dead
    public interface IEmergencyDispatchService
    {
        Task<IEnumerable<EmergencyDispatchResponse>> GetAllAsync(CancellationToken cancellationToken = default);

        // get all dispatches for one patient — useful for patient history
        Task<IEnumerable<EmergencyDispatchResponse>> GetByPatientAsync(int patientId, CancellationToken cancellationToken = default);

        // get all dispatches handled by one ambulance — useful for ambulance dashboard
        Task<IEnumerable<EmergencyDispatchResponse>> GetByAmbulanceAsync(int ambulanceId, CancellationToken cancellationToken = default);

        // create a new dispatch when an emergency is triggered
        Task<Result<EmergencyDispatchResponse>> AddAsync(EmergencyDispatchRequest request, CancellationToken cancellationToken = default);

        // update status as the dispatch progresses: Pending → OnTheWay → Arrived → Resolved
        // also auto-stamps ArrivedAt and ResolvedAt timestamps when those statuses are set
        Task<Result> UpdateStatusAsync(int id, string status, CancellationToken cancellationToken = default);
    }
}
