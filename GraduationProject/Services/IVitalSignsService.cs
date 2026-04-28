namespace GraduationProject.Services
{
    public interface IVitalSignsService
    {
        Task<IEnumerable<VitalSigns>> GetAllAsync();
        Task<VitalSigns> AddAsync(VitalSigns vital);
    }
}