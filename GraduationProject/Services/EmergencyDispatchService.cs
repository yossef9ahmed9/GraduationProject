using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Services
{
    public class EmergencyDispatchService(AppDbContext context) : IEmergencyDispatchService
    {
        private readonly AppDbContext _context = context;

        private static readonly Dictionary<string, HashSet<string>> ValidTransitions = new()
        {
            { "Pending",   new() { "OnTheWay", "Cancelled" } },
            { "OnTheWay",  new() { "Arrived",  "Cancelled" } },
            { "Arrived",   new() { "Resolved", "Cancelled" } },
            { "Resolved",  new() },
            { "Cancelled", new() },
        };

        public async Task<PagedResponse<EmergencyDispatchResponse>> GetAllAsync(
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            return await _context.EmergencyDispatches
                .AsNoTracking()
                .OrderBy(e => e.Id)
                .ProjectToType<EmergencyDispatchResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<Result<EmergencyDispatchResponse>> GetByIdAsync(
            int id,
            CancellationToken cancellationToken = default)
        {
            var dispatch = await _context.EmergencyDispatches
                .AsNoTracking()
                .ProjectToType<EmergencyDispatchResponse>()
                .FirstOrDefaultAsync(e => e.Id == id, cancellationToken);

            return dispatch is not null
                ? Result.Success(dispatch)
                : Result.Failure<EmergencyDispatchResponse>(
                    new Error("Dispatch.NotFound",
                        "No dispatch found with the given ID",
                        StatusCodes.Status404NotFound));
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
            await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);

            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
            {
                await transaction.RollbackAsync(cancellationToken);
                return Result.Failure<EmergencyDispatchResponse>(
                    new Error("Dispatch.PatientNotFound",
                        "No patient found with the given ID",
                        StatusCodes.Status404NotFound));
            }

            // Atomic claim: only succeeds if ambulance is still Available
            var rowsAffected = await _context.Ambulances
                .Where(a => a.Id == request.AmbulanceId && a.AvailabilityStatus == "Available")
                .ExecuteUpdateAsync(s => s.SetProperty(a => a.AvailabilityStatus, "Busy"),
                    cancellationToken);

            if (rowsAffected == 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return Result.Failure<EmergencyDispatchResponse>(
                    new Error("Dispatch.AmbulanceNotAvailable",
                        "This ambulance is not available for dispatch",
                        StatusCodes.Status400BadRequest));
            }

            var ambulance = await _context.Ambulances
                .FindAsync(new object[] { request.AmbulanceId }, cancellationToken);

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

            var patient = await _context.Patients
                .FindAsync(new object[] { request.PatientId }, cancellationToken);
            if (patient is not null)
                patient.IsInEmergency = true;

            await _context.EmergencyDispatches.AddAsync(dispatch, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

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

            if (!ValidTransitions.TryGetValue(dispatch.Status, out var allowed) || !allowed.Contains(status))
                return Result.Failure(
                    new Error("Dispatch.InvalidStatusTransition",
                        $"Cannot transition from '{dispatch.Status}' to '{status}'",
                        StatusCodes.Status400BadRequest));

            dispatch.Status = status;

            if (status == "Arrived")
                dispatch.ArrivedAt = DateTime.UtcNow;
                // Ambulance stays Busy — still with patient

            if (status == "Resolved" || status == "Cancelled")
            {
                if (status == "Resolved")
                    dispatch.ResolvedAt = DateTime.UtcNow;

                // Free the ambulance
                if (dispatch.Ambulance is not null)
                    dispatch.Ambulance.AvailabilityStatus = "Available";

                // Only clear emergency flag if no other active dispatch for this patient
                var otherActive = await _context.EmergencyDispatches
                    .AnyAsync(d =>
                        d.PatientId == dispatch.PatientId &&
                        d.Id != dispatch.Id &&
                        (d.Status == "Pending" || d.Status == "OnTheWay" || d.Status == "Arrived"),
                        cancellationToken);

                if (!otherActive && dispatch.Patient is not null)
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
