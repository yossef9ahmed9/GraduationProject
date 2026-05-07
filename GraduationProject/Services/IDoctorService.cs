using GraduationProject.Contracts.Doctors;

namespace GraduationProject.Services
{
    

        public interface IDoctorService
        {
            Task<IEnumerable<DoctorResponse>> GetAllAsync(CancellationToken cancellationToken = default);
            Task<Result<DoctorResponse>> GetAsync(int id, CancellationToken cancellationToken = default);
            Task<Result<DoctorResponse>> AddAsync(DoctorRequest doctor, CancellationToken cancellationToken = default);
            Task<Result> UpdateAsync(int id, DoctorRequest doctor, CancellationToken cancellationToken = default);
            Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default);
        }
    }
