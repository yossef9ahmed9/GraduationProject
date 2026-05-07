using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Services
{
    public interface IVitalSignsService
    {
        Task<IEnumerable<VitalSignsResponse>> GetAllAsync(CancellationToken cancellationToken = default);
        Task<Result<VitalSignsResponse>> AddAsync(VitalSignsRequest request, CancellationToken cancellationToken = default);
    }
}