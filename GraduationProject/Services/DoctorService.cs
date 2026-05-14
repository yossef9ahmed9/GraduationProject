using GraduationProject.Contracts.Doctors;

namespace GraduationProject.Services
{
    public class DoctorService(AppDbContext context) : IDoctorService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<DoctorResponse>> GetAllAsync(CancellationToken cancellationToken = default)
        {
            return await _context.Doctors
                .AsNoTracking()
                .ProjectToType<DoctorResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<Result<DoctorResponse>> GetAsync(int id, CancellationToken cancellationToken = default)
        {
            var doctor = await _context.Doctors
                .AsNoTracking()
                .Where(d => d.Id == id)
                .ProjectToType<DoctorResponse>()
                .FirstOrDefaultAsync(cancellationToken);

            return doctor == null
                ? Result.Failure<DoctorResponse>(DoctorErors.DoctorNotFound)
                : Result.Success(doctor);
        }

        public async Task<Result<DoctorResponse>> AddAsync(DoctorRequest request, CancellationToken cancellationToken = default)
        {
            var exists = await _context.Doctors
                .AnyAsync(d => d.Email == request.Email, cancellationToken);

            if (exists)
                return Result.Failure<DoctorResponse>(DoctorErors.DuplicatedDoctor);

            var doctor = request.Adapt<Doctor>();

            await _context.Doctors.AddAsync(doctor, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(doctor.Adapt<DoctorResponse>());
        }

        public async Task<Result> UpdateAsync(int id,DoctorRequest request,CancellationToken cancellationToken = default)
        {
            var doctor = await _context.Doctors.FindAsync(new object[] { id }, cancellationToken);

            if (doctor == null)
                return Result.Failure(DoctorErors.DoctorNotFound);

            var exists = await _context.Doctors
                .AnyAsync(d => d.Email == request.Email && d.Id != id, cancellationToken);

            if (exists)
                return Result.Failure(DoctorErors.DuplicatedDoctor);

            request.Adapt(doctor);

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }

        public async Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default)
        {
            var doctor = await _context.Doctors.FindAsync(new object[] { id }, cancellationToken);

            if (doctor == null)
                return Result.Failure(DoctorErors.DoctorNotFound);

            doctor.IsDeleted = true;
            doctor.DeletedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}