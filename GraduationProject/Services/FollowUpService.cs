namespace GraduationProject.Services
{
    public class FollowUpService(AppDbContext context) : IFollowUpService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<FollowUp>> GetAllAsync() =>
            await _context.FollowUps.ToListAsync();

        public async Task<FollowUp> AddAsync(FollowUp followUp)
        {
            await _context.FollowUps.AddAsync(followUp);
            await _context.SaveChangesAsync();
            return followUp;
        }
    }
}