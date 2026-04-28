namespace GraduationProject.Services
{
    public class SensorService(AppDbContext context) : ISensorService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<Sensor>> GetAllAsync() =>
            await _context.Sensors.ToListAsync();

        public async Task<Sensor?> GetAsync(int id) =>
            await _context.Sensors.FindAsync(id);

        public async Task<Sensor> AddAsync(Sensor sensor)
        {
            await _context.Sensors.AddAsync(sensor);
            await _context.SaveChangesAsync();
            return sensor;
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var sensor = await GetAsync(id);
            if (sensor == null) return false;

            _context.Sensors.Remove(sensor);
            await _context.SaveChangesAsync();
            return true;
        }
    }
}