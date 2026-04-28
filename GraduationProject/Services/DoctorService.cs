namespace GraduationProject.Services
{
    public class DoctorService(AppDbContext context) : IDoctorService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<Doctor>> GetAllAsync() =>
            await _context.Doctors.AsNoTracking().ToListAsync();

        public async Task<Doctor?> GetAsync(int id) =>
            await _context.Doctors.FindAsync(id);

        public async Task<Doctor> AddAsync(Doctor doctor)
        {
            await _context.Doctors.AddAsync(doctor);
            await _context.SaveChangesAsync();
            return doctor;
        }

        public async Task<bool> UpdateAsync(int id, Doctor doctor)
        {
            var existing = await GetAsync(id);
            if (existing == null) return false;

            existing.Name = doctor.Name;
            existing.Phone = doctor.Phone;
            existing.Email = doctor.Email;
            existing.Specialization = doctor.Specialization;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var doctor = await GetAsync(id);
            if (doctor == null) return false;

            _context.Doctors.Remove(doctor);
            await _context.SaveChangesAsync();
            return true;
        }
    }
}