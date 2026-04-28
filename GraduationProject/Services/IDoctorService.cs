namespace GraduationProject.Services
{
    public interface IDoctorService
    {
        Task<IEnumerable<Doctor>> GetAllAsync();
        Task<Doctor?> GetAsync(int id);
        Task<Doctor> AddAsync(Doctor doctor);
        Task<bool> UpdateAsync(int id, Doctor doctor);
        Task<bool> DeleteAsync(int id);
    }
}