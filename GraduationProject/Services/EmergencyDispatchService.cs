using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Services
{
    public class EmergencyDispatchService(AppDbContext context) : IEmergencyDispatchService
    {
        private readonly AppDbContext _context = context;

        public async Task<PagedResponse<EmergencyDispatchResponse>> GetAllAsync(
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            return await _context.EmergencyDispatches
                .AsNoTracking()
                .ProjectToType<EmergencyDispatchResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<PagedResponse<EmergencyDispatchResponse>> GetByPatientAsync(
            int patientId,
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            return await _context.EmergencyDispatches
                .AsNoTracking()
                .Where(e => e.PatientId == patientId)
                .OrderByDescending(e => e.DispatchedAt)
                .ProjectToType<EmergencyDispatchResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<PagedResponse<EmergencyDispatchResponse>> GetByAmbulanceAsync(
            int ambulanceId,
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            return await _context.EmergencyDispatches
                .AsNoTracking()
                .Where(e => e.AmbulanceId == ambulanceId)
                .OrderByDescending(e => e.DispatchedAt)
                .ProjectToType<EmergencyDispatchResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<Result<EmergencyDispatchResponse>> AddAsync(
            EmergencyDispatchRequest request,
            CancellationToken cancellationToken = default)
        {
            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
                return Result.Failure<EmergencyDispatchResponse>(
                    new Error("Dispatch.PatientNotFound",
                        "No patient found with the given ID",
                        StatusCodes.Status404NotFound));

            var ambulance = await _context.Ambulances
                .FirstOrDefaultAsync(a => a.Id == request.AmbulanceId, cancellationToken);

            if (ambulance is null)
                return Result.Failure<EmergencyDispatchResponse>(
                    new Error("Dispatch.AmbulanceNotFound",
                        "No ambulance found with the given ID",
                        StatusCodes.Status404NotFound));

            if (ambulance.AvailabilityStatus != "Available")
                return Result.Failure<EmergencyDispatchResponse>(
                    new Error("Dispatch.AmbulanceNotAvailable",
                        "This ambulance is not available for dispatch",
                        StatusCodes.Status400BadRequest));

            var dispatch = new EmergencyDispatch
            {
                PatientId        = request.PatientId,
                AmbulanceId      = request.AmbulanceId,
                PatientLatitude  = request.PatientLatitude,
                PatientLongitude = request.PatientLongitude,
                Notes            = request.Notes,
                DispatchedAt     = DateTime.UtcNow,
                Status           = "Pending"
            };

            // Mark ambulance busy so it won't be double-dispatched
            ambulance.AvailabilityStatus = "Busy";

            // Mark patient as in an active emergency so auto-emergency doesn't re-trigger
            var patient = await _context.Patients
                .FindAsync(new object[] { request.PatientId }, cancellationToken);
            if (patient is not null)
                patient.IsInEmergency = true;

            await _context.EmergencyDispatches.AddAsync(dispatch, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(dispatch.Adapt<EmergencyDispatchResponse>());
        }

        public async Task<Result> UpdateStatusAsync(
            int id, string status,
            CancellationToken cancellationToken = default)
        {
            var dispatch = await _context.EmergencyDispatches
                .Include(e => e.Ambulance)
                .Include(e => e.Patient)
                .FirstOrDefaultAsync(e => e.Id == id, cancellationToken);

            if (dispatch is null)
                return Result.Failure(
                    new Error("Dispatch.NotFound",
                        "No dispatch found with the given ID",
                        StatusCodes.Status404NotFound));

            dispatch.Status = status;

            if (status == "Arrived")
                dispatch.ArrivedAt = DateTime.UtcNow;

            if (status == "Resolved" || status == "Cancelled")
            {
                dispatch.ResolvedAt = DateTime.UtcNow;
                dispatch.Ambulance.AvailabilityStatus = "Available";
                dispatch.Patient.IsInEmergency = false;
            }

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }

        // FIXED: added — entity had ISoftDeletable columns but no delete endpoint existed
        // Only resolved or cancelled dispatches may be deleted to prevent hiding an active emergency
        public async Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default)
        {
            var dispatch = await _context.EmergencyDispatches
                .FirstOrDefaultAsync(e => e.Id == id, cancellationToken);

            if (dispatch is null)
                return Result.Failure(
                    new Error("Dispatch.NotFound",
                        "No dispatch found with the given ID",
                        StatusCodes.Status404NotFound));

            if (dispatch.Status != "Resolved" && dispatch.Status != "Cancelled")
                return Result.Failure(
                    new Error("Dispatch.CannotDelete",
                        "Only resolved or cancelled dispatches can be deleted",
                        StatusCodes.Status400BadRequest));

            dispatch.IsDeleted    = true;
            dispatch.DeletedAtUtc = DateTime.UtcNow;

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}
