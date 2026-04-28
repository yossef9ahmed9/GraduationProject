namespace GraduationProject.Services
{
    public class VitalSignsService(AppDbContext context) : IVitalSignsService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<VitalSigns>> GetAllAsync() =>
            await _context.VitalSigns.ToListAsync();

        public async Task<VitalSigns> AddAsync(VitalSigns vital)
        {
            await _context.VitalSigns.AddAsync(vital);
            await _context.SaveChangesAsync();
            return vital;
        }
    }
}