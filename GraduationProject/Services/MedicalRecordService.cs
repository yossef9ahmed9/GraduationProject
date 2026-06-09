using GraduationProject.Contracts.MedicalRecord;
using GraduationProject.Contracts.Patients;

namespace GraduationProject.Services
{
    public class MedicalRecordService(AppDbContext context) : IMedicalRecordService
    {
        private readonly AppDbContext _context = context;

        public async Task<Result<MedicalRecordEntryResponse>> AddEntryAsync(
            int patientId,
            string authorEmail,
            string authorName,
            string authorRole,
            UpdateMedicalRecordRequest request,
            CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients
                .FirstOrDefaultAsync(p => p.Id == patientId, cancellationToken);

            if (patient is null)
                return Result.Failure<MedicalRecordEntryResponse>(
                    new Error("MedicalRecord.PatientNotFound",
                              "Patient not found.",
                              StatusCodes.Status404NotFound));

            // Update the current snapshot on Patient so GET /patients still returns
            // the latest values without joining the history table
            if (request.MedicalRecord   is not null) patient.MedicalRecord   = request.MedicalRecord;
            if (request.ChronicDiseases is not null) patient.ChronicDiseases = request.ChronicDiseases;
            if (request.Allergies       is not null) patient.Allergies       = request.Allergies;
            if (request.BloodType       is not null) patient.BloodType       = request.BloodType;

            // Append a history entry — never overwrite previous entries
            var entry = new MedicalRecordEntry
            {
                PatientId       = patientId,
                AuthorEmail     = authorEmail,
                AuthorName      = authorName,
                AuthorRole      = authorRole,
                MedicalRecord   = request.MedicalRecord,
                ChronicDiseases = request.ChronicDiseases,
                Allergies       = request.Allergies,
                BloodType       = request.BloodType,
                CreatedAt       = DateTime.UtcNow,
            };

            await _context.MedicalRecordEntries.AddAsync(entry, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(Map(entry));
        }

        public async Task<IReadOnlyList<MedicalRecordEntryResponse>> GetHistoryAsync(
            int patientId,
            CancellationToken cancellationToken = default)
        {
            return await _context.MedicalRecordEntries
                .AsNoTracking()
                .Where(e => e.PatientId == patientId)
                .OrderByDescending(e => e.CreatedAt)
                .Select(e => Map(e))
                .ToListAsync(cancellationToken);
        }

        private static MedicalRecordEntryResponse Map(MedicalRecordEntry e) =>
            new(e.Id, e.PatientId, e.AuthorEmail, e.AuthorName, e.AuthorRole,
                e.MedicalRecord, e.ChronicDiseases, e.Allergies, e.BloodType, e.CreatedAt);
    }
}
