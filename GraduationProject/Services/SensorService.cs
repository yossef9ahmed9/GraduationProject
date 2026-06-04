using GraduationProject.Contracts.Sensors;

namespace GraduationProject.Services
{
    public class SensorService(AppDbContext context) : ISensorService
    {
        private readonly AppDbContext _context = context;

        public async Task<PagedResponse<SensorResponse>> GetAllAsync(int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return await _context.Sensors
                .AsNoTracking()
                .OrderBy(s => s.Id)
                .ProjectToType<SensorResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<Result<SensorResponse>> GetAsync(int id, CancellationToken cancellationToken = default)
        {
            var sensor = await _context.Sensors
                .AsNoTracking()
                .Where(s => s.Id == id)
                .ProjectToType<SensorResponse>()
                .FirstOrDefaultAsync(cancellationToken);

            return sensor == null
                ? Result.Failure<SensorResponse>(SensorErrors.SensorNotFound)
                : Result.Success(sensor);
        }

        public async Task<Result<SensorResponse>> AddAsync(SensorRequest request, CancellationToken cancellationToken = default)
        {
            var sensor = request.Adapt<Sensor>();

            await _context.Sensors.AddAsync(sensor, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(sensor.Adapt<SensorResponse>());
        }

        public async Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default)
        {
            var sensor = await _context.Sensors.FindAsync(new object[] { id }, cancellationToken);

            if (sensor == null)
                return Result.Failure(SensorErrors.SensorNotFound);

            sensor.IsDeleted = true;
            sensor.DeletedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}
