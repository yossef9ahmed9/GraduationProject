namespace GraduationProject.Services
{
    public interface ISensorService
    {
        Task<IEnumerable<Sensor>> GetAllAsync();
        Task<Sensor?> GetAsync(int id);
        Task<Sensor> AddAsync(Sensor sensor);
        Task<bool> DeleteAsync(int id);
    }
}