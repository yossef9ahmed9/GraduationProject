using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Services
{
    public interface IVitalSignsService
    {
        Task<PagedResponse<VitalSignsResponse>> GetAllAsync(
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default);

        Task<PagedResponse<VitalSignsResponse>> GetByPatientAsync(
            int patientId,
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default);

        Task<Result<VitalSignsResponse>> GetLatestByPatientAsync(
            int patientId,
            CancellationToken cancellationToken = default);

        Task<Result<VitalSignsResponse>> AddAsync(
            VitalSignsRequest request,
            CancellationToken cancellationToken = default);
    }
}
