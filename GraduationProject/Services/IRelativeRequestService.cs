using GraduationProject.Contracts.RelativeRequests;

namespace GraduationProject.Services
{
    public interface IRelativeRequestService
    {
        Task<Result<RelativeRequestResponse>> SendRequestAsync(
            string relativeEmail,
            int patientId,
            CancellationToken cancellationToken = default);

        Task<IReadOnlyList<RelativeRequestResponse>> GetRequestsForPatientAsync(
            string patientEmail,
            CancellationToken cancellationToken = default);

        Task<IReadOnlyList<RelativeRequestStatusResponse>> GetMyRequestStatusAsync(
            string relativeEmail,
            CancellationToken cancellationToken = default);

        Task<Result> ApproveAsync(
            int requestId,
            string patientEmail,
            CancellationToken cancellationToken = default);

        Task<Result> RejectAsync(
            int requestId,
            string patientEmail,
            CancellationToken cancellationToken = default);

        Task<IReadOnlyList<PatientSearchResult>> SearchPatientsAsync(
            string query,
            CancellationToken cancellationToken = default);
    }
}
