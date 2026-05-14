using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Services
{
    // NEW FILE: implementation of IEmergencyDispatchService
    // the EmergencyDispatch entity, DbSet, and migrations already existed
    // this was the missing piece that makes the feature actually reachable via the API
    public class EmergencyDispatchService(AppDbContext context) : IEmergencyDispatchService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<EmergencyDispatchResponse>> GetAllAsync(
            CancellationToken cancellationToken = default)
        {
            return await _context.EmergencyDispatches
                .AsNoTracking()
                .ProjectToType<EmergencyDispatchResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<IEnumerable<EmergencyDispatchResponse>> GetByPatientAsync(
            int patientId,
            CancellationToken cancellationToken = default)
        {
            return await _context.EmergencyDispatches
                .AsNoTracking()
                .Where(e => e.PatientId == patientId)
                .OrderByDescending(e => e.DispatchedAt) // newest first
                .ProjectToType<EmergencyDispatchResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<IEnumerable<EmergencyDispatchResponse>> GetByAmbulanceAsync(
            int ambulanceId,
            CancellationToken cancellationToken = default)
        {
            return await _context.EmergencyDispatches
                .AsNoTracking()
                .Where(e => e.AmbulanceId == ambulanceId)
                .OrderByDescending(e => e.DispatchedAt) // newest first
                .ProjectToType<EmergencyDispatchResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<Result<EmergencyDispatchResponse>> AddAsync(
            EmergencyDispatchRequest request,
            CancellationToken cancellationToken = default)
        {
            // verify the patient exists before creating a dispatch for them
            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
                return Result.Failure<EmergencyDispatchResponse>(
                    new Error("Dispatch.PatientNotFound",
                        "No patient found with the given ID",
                        StatusCodes.Status404NotFound));

            // verify the ambulance exists and is available
            var ambulance = await _context.Ambulances
                .FirstOrDefaultAsync(a => a.Id == request.AmbulanceId, cancellationToken);

            if (ambulance is null)
                return Result.Failure<EmergencyDispatchResponse>(
                    new Error("Dispatch.AmbulanceNotFound",
                        "No ambulance found with the given ID",
                        StatusCodes.Status404NotFound));

            // only dispatch an available ambulance
            if (ambulance.AvailabilityStatus != "Available")
                return Result.Failure<EmergencyDispatchResponse>(
                    new Error("Dispatch.AmbulanceNotAvailable",
                        "This ambulance is not available for dispatch",
                        StatusCodes.Status400BadRequest));

            var dispatch = new EmergencyDispatch
            {
                PatientId = request.PatientId,
                AmbulanceId = request.AmbulanceId,
                PatientLatitude = request.PatientLatitude,
                PatientLongitude = request.PatientLongitude,
                Notes = request.Notes,
                DispatchedAt = DateTime.UtcNow,
                Status = "Pending"
            };

            // mark ambulance as busy so it won't be dispatched twice
            ambulance.AvailabilityStatus = "Busy";

            // NEW: also mark the patient as in an active emergency
            // so the auto-emergency service won't double-dispatch for the same patient
            var patient = await _context.Patients.FindAsync(
                new object[] { request.PatientId }, cancellationToken);
            if (patient is not null)
                patient.IsInEmergency = true;

            await _context.EmergencyDispatches.AddAsync(dispatch, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(dispatch.Adapt<EmergencyDispatchResponse>());
        }

        public async Task<Result> UpdateStatusAsync(
            int id,
            string status,
            CancellationToken cancellationToken = default)
        {
            var dispatch = await _context.EmergencyDispatches
                .Include(e => e.Ambulance) // need ambulance to update availability on resolve
                .Include(e => e.Patient)   // NEW: need patient to clear IsInEmergency
                .FirstOrDefaultAsync(e => e.Id == id, cancellationToken);

            if (dispatch is null)
                return Result.Failure(
                    new Error("Dispatch.NotFound",
                        "No dispatch found with the given ID",
                        StatusCodes.Status404NotFound));

            dispatch.Status = status;

            // auto-stamp timestamps as the dispatch moves through its lifecycle
            if (status == "Arrived")
                dispatch.ArrivedAt = DateTime.UtcNow;

            if (status == "Resolved" || status == "Cancelled")
            {
                dispatch.ResolvedAt = DateTime.UtcNow;

                // free the ambulance back up when the case is closed
                dispatch.Ambulance.AvailabilityStatus = "Available";

                // NEW: clear the patient's emergency flag so the auto-emergency service
                // can trigger again if future vitals become critical
                dispatch.Patient.IsInEmergency = false;
            }

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}
