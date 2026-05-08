using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Services
{
    public interface IVitalSignsService
    {
        Task<IEnumerable<VitalSignsResponse>> GetAllAsync(
            CancellationToken cancellationToken = default);

        // NEW: get all vitals for one patient
        Task<IEnumerable<VitalSignsResponse>> GetByPatientAsync(
            int patientId,
            CancellationToken cancellationToken = default);

        // NEW: get only the latest reading for a patient
        Task<Result<VitalSignsResponse>> GetLatestByPatientAsync(
            int patientId,
            CancellationToken cancellationToken = default);

        Task<Result<VitalSignsResponse>> AddAsync(
            VitalSignsRequest request,
            CancellationToken cancellationToken = default);
    }
}