using GraduationProject.Contracts.Doctors;

namespace GraduationProject.Services
{
    

        public interface IDoctorService
        {
            Task<PagedResponse<DoctorResponse>> GetAllAsync(int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default);
            Task<Result<DoctorResponse>> GetAsync(int id, CancellationToken cancellationToken = default);
            Task<Result<DoctorResponse>> AddAsync(DoctorRequest doctor, CancellationToken cancellationToken = default);
            Task<Result> UpdateAsync(int id, DoctorRequest doctor, CancellationToken cancellationToken = default);
            Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default);
        }
    }
