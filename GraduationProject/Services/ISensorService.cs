using GraduationProject.Contracts.Sensors;

namespace GraduationProject.Services
{
    public interface ISensorService
    {
        Task<PagedResponse<SensorResponse>> GetAllAsync(int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);
        Task<Result<SensorResponse>> GetAsync(int id, CancellationToken cancellationToken = default);
        Task<Result<SensorResponse>> AddAsync(SensorRequest request, CancellationToken cancellationToken = default);
        Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default);
    }
}