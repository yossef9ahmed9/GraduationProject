using GraduationProject.Contracts.Labs;

namespace GraduationProject.Services
{
    public interface ILabService
    {
        Task<PagedResponse<LabResponse>> GetAllAsync(int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);
        Task<Result<LabResponse>> GetAsync(int id, CancellationToken cancellationToken = default);
        Task<Result<LabResponse>> AddAsync(LabRequest request, CancellationToken cancellationToken = default);
        Task<Result> UpdateAsync(int id, LabRequest request, CancellationToken cancellationToken = default);
        Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default);
    }
}
