using GraduationProject.Entities;

namespace GraduationProject.Services
{
    public interface IPatientService
    {
        Task<IEnumerable<Patient>>GetAllPatientsAsync(CancellationToken cancellationToken = default); 
        Task<Patient> GetPatientAsync(int id, CancellationToken cancellationToken = default);
        Task<Patient> AddPatientAsync(Patient patient, CancellationToken cancellationToken = default);
        Task<bool>UpdatePatientAsync(int id, Patient patient, CancellationToken cancellationToken = default);
        Task<bool> DeletePatientAsync(int id, CancellationToken cancellationToken = default);
    }
}
