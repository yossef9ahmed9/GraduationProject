using GraduationProject.Contracts.RelativeRequests;
using GraduationProject.Entities;
using GraduationProject.Presistence;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Services
{
    public class RelativeRequestService(AppDbContext context) : IRelativeRequestService
    {
        private readonly AppDbContext _context = context;

        public async Task<Result<RelativeRequestResponse>> SendRequestAsync(
            string relativeEmail,
            int patientId,
            CancellationToken cancellationToken = default)
        {
            var relative = await _context.Relatives
                .FirstOrDefaultAsync(r => r.Email == relativeEmail, cancellationToken);

            if (relative is null)
                return Result.Failure<RelativeRequestResponse>(new Error(
                    "RelativeRequest.RelativeNotFound",
                    "Relative profile not found.",
                    StatusCodes.Status404NotFound));

            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == patientId, cancellationToken);

            if (!patientExists)
                return Result.Failure<RelativeRequestResponse>(new Error(
                    "RelativeRequest.PatientNotFound",
                    "Patient not found.",
                    StatusCodes.Status404NotFound));

            var existing = await _context.RelativePatientRequests
                .FirstOrDefaultAsync(r =>
                    r.RelativeId == relative.Id &&
                    r.PatientId  == patientId   &&
                    r.Status     != "Rejected",
                    cancellationToken);

            if (existing is not null)
                return Result.Failure<RelativeRequestResponse>(new Error(
                    "RelativeRequest.AlreadyExists",
                    $"A request already exists with status: {existing.Status}.",
                    StatusCodes.Status409Conflict));

            var request = new RelativePatientRequest
            {
                RelativeId = relative.Id,
                PatientId  = patientId,
                Status     = "Pending",
                CreatedAt  = DateTime.UtcNow,
            };

            await _context.RelativePatientRequests.AddAsync(request, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(Map(request, relative.Name, relative.Phone, relative.RelationType, ""));
        }

        public async Task<IReadOnlyList<RelativeRequestResponse>> GetRequestsForPatientAsync(
            string patientEmail,
            CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Email == patientEmail, cancellationToken);

            if (patient is null) return [];

            return await _context.RelativePatientRequests
                .AsNoTracking()
                .Where(r => r.PatientId == patient.Id)
                .Select(r => new RelativeRequestResponse(
                    r.Id,
                    r.RelativeId,
                    r.Relative.Name,
                    r.Relative.Phone,
                    r.Relative.RelationType,
                    r.PatientId,
                    r.Status,
                    r.CreatedAt,
                    r.UpdatedAt))
                .ToListAsync(cancellationToken);
        }

        public async Task<IReadOnlyList<RelativeRequestStatusResponse>> GetMyRequestStatusAsync(
            string relativeEmail,
            CancellationToken cancellationToken = default)
        {
            var relative = await _context.Relatives
                .AsNoTracking()
                .FirstOrDefaultAsync(r => r.Email == relativeEmail, cancellationToken);

            if (relative is null) return [];

            return await _context.RelativePatientRequests
                .AsNoTracking()
                .Where(r => r.RelativeId == relative.Id)
                .Select(r => new RelativeRequestStatusResponse(
                    r.Id,
                    r.PatientId,
                    r.Patient.Name,
                    r.Status,
                    r.CreatedAt,
                    r.UpdatedAt))
                .ToListAsync(cancellationToken);
        }

        public async Task<Result> ApproveAsync(
            int requestId,
            string patientEmail,
            CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients
                .FirstOrDefaultAsync(p => p.Email == patientEmail, cancellationToken);

            if (patient is null)
                return Result.Failure(new Error(
                    "RelativeRequest.PatientNotFound",
                    "Patient not found.",
                    StatusCodes.Status404NotFound));

            var request = await _context.RelativePatientRequests
                .Include(r => r.Relative)
                .FirstOrDefaultAsync(r => r.Id == requestId && r.PatientId == patient.Id, cancellationToken);

            if (request is null)
                return Result.Failure(new Error(
                    "RelativeRequest.NotFound",
                    "Request not found.",
                    StatusCodes.Status404NotFound));

            if (request.Status == "Approved")
                return Result.Failure(new Error(
                    "RelativeRequest.AlreadyApproved",
                    "Already approved.",
                    StatusCodes.Status409Conflict));

            request.Status             = "Approved";
            request.UpdatedAt          = DateTime.UtcNow;
            request.Relative.PatientId = patient.Id;

            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }

        public async Task<Result> RejectAsync(
            int requestId,
            string patientEmail,
            CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients
                .FirstOrDefaultAsync(p => p.Email == patientEmail, cancellationToken);

            if (patient is null)
                return Result.Failure(new Error(
                    "RelativeRequest.PatientNotFound",
                    "Patient not found.",
                    StatusCodes.Status404NotFound));

            var request = await _context.RelativePatientRequests
                .FirstOrDefaultAsync(r => r.Id == requestId && r.PatientId == patient.Id, cancellationToken);

            if (request is null)
                return Result.Failure(new Error(
                    "RelativeRequest.NotFound",
                    "Request not found.",
                    StatusCodes.Status404NotFound));

            request.Status    = "Rejected";
            request.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }

        public async Task<IReadOnlyList<PatientSearchResult>> SearchPatientsAsync(
            string query,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(query) || query.Length < 2)
                return [];

            var q = query.Trim().ToLower();

            // Search by name, email, or phone
            return await _context.Patients
                .AsNoTracking()
                .Where(p => p.Name.ToLower().Contains(q) ||
                            (p.Email != null && p.Email.ToLower().Contains(q)) ||
                            (p.Phone != null && p.Phone.Contains(q)))
                .Select(p => new PatientSearchResult(
                    p.Id, p.Name, p.Email ?? "", p.Phone, p.Gender))
                .Take(20)
                .ToListAsync(cancellationToken);
        }

        private static RelativeRequestResponse Map(
            RelativePatientRequest r,
            string name, string phone, string relationType, string patientName) =>
            new(r.Id, r.RelativeId, name, phone, relationType,
                r.PatientId, r.Status, r.CreatedAt, r.UpdatedAt);
    }
}
