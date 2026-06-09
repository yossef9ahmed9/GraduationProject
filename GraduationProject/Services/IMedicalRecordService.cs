using GraduationProject.Contracts.MedicalRecord;
using GraduationProject.Contracts.Patients;

namespace GraduationProject.Services
{
    public interface IMedicalRecordService
    {
        Task<Result<MedicalRecordEntryResponse>> AddEntryAsync(
            int patientId,
            string authorEmail,
            string authorName,
            string authorRole,
            UpdateMedicalRecordRequest request,
            CancellationToken cancellationToken = default);

        Task<IReadOnlyList<MedicalRecordEntryResponse>> GetHistoryAsync(
            int patientId,
            CancellationToken cancellationToken = default);
    }
}
