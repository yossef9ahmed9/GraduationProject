using GraduationProject.Contracts.Sensors;

namespace GraduationProject.Services
{
    public interface ISensorService
    {
        Task<IEnumerable<SensorResponse>> GetAllAsync(CancellationToken cancellationToken = default);
        Task<Result<SensorResponse>> GetAsync(int id, CancellationToken cancellationToken = default);
        Task<Result<SensorResponse>> AddAsync(SensorRequest request, CancellationToken cancellationToken = default);
        Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default);
    }
}