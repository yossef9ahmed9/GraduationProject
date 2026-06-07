using GraduationProject.Contracts.DispatchRequests;

namespace GraduationProject.Services
{
    public interface IDispatchRequestService
    {
        Task<IReadOnlyList<ActiveDispatchResponse>> GetMyActiveDispatchesAsync(
            string ambulanceEmail,
            CancellationToken cancellationToken = default);

        Task<Result<DispatchActionResponse>> AcceptAsync(
            int dispatchId,
            string ambulanceEmail,
            CancellationToken cancellationToken = default);

        Task<Result<DispatchActionResponse>> RejectAsync(
            int dispatchId,
            string ambulanceEmail,
            CancellationToken cancellationToken = default);
    }
}
