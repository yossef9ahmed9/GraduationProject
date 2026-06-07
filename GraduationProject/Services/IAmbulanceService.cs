using GraduationProject.Contracts.Ambulances;

namespace GraduationProject.Services
{
    public interface IAmbulanceService
    {
        Task<PagedResponse<AmbulanceResponse>> GetAllAsync(
            string? callerEmail, bool isAmbulanceRole,
            int pageNumber = 1, int pageSize = 20,
            CancellationToken cancellationToken = default);

        Task<IReadOnlyList<AmbulanceResponse>> GetAvailableAsync(
            CancellationToken cancellationToken = default);

        Task<Result<AmbulanceResponse>> GetByIdAsync(
            int id, string? callerEmail, bool isAmbulanceRole,
            CancellationToken cancellationToken = default);

        Task<PagedResponse<AmbulanceDispatchSummary>> GetDispatchesAsync(
            int id, string? callerEmail, bool isAmbulanceRole,
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default);

        Task<Result> UpdateAvailabilityAsync(
            int id, string status, string callerEmail, bool isAmbulanceRole,
            CancellationToken cancellationToken = default);

        Task<Result> SignInAsync(
            string callerEmail,
            CancellationToken cancellationToken = default);

        Task<Result> SignOutAsync(
            string callerEmail,
            CancellationToken cancellationToken = default);
    }
}
