using GraduationProject.Contracts.DispatchRequests;
using GraduationProject.Entities;
using GraduationProject.Presistence;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Services
{
    public class DispatchRequestService(AppDbContext context) : IDispatchRequestService
    {
        private readonly AppDbContext _context = context;

        public async Task<IReadOnlyList<ActiveDispatchResponse>> GetMyActiveDispatchesAsync(
            string ambulanceEmail,
            CancellationToken cancellationToken = default)
        {
            var ambulance = await _context.Ambulances
                .AsNoTracking()
                .FirstOrDefaultAsync(a => a.Email == ambulanceEmail, cancellationToken);

            if (ambulance is null) return [];

            return await _context.EmergencyDispatches
                .AsNoTracking()
                .Where(d => d.AmbulanceId == ambulance.Id &&
                            (d.Status == "Pending" ||
                             d.Status == "OnTheWay" ||
                             d.Status == "Arrived"))
                .OrderByDescending(d => d.DispatchedAt)
                .Select(d => new ActiveDispatchResponse(
                    d.Id,
                    d.Status,
                    d.DispatchedAt,
                    d.PatientLatitude,
                    d.PatientLongitude,
                    d.Notes,
                    d.PatientId,
                    d.Patient.Name,
                    d.Patient.Phone))
                .ToListAsync(cancellationToken);
        }

        public async Task<Result<DispatchActionResponse>> AcceptAsync(
            int dispatchId,
            string ambulanceEmail,
            CancellationToken cancellationToken = default)
        {
            var ambulance = await _context.Ambulances
                .FirstOrDefaultAsync(a => a.Email == ambulanceEmail, cancellationToken);

            if (ambulance is null)
                return Result.Failure<DispatchActionResponse>(new Error(
                    "Dispatch.AmbulanceNotFound",
                    "Ambulance not found.",
                    StatusCodes.Status404NotFound));

            var dispatch = await _context.EmergencyDispatches
                .FirstOrDefaultAsync(d =>
                    d.Id == dispatchId && d.AmbulanceId == ambulance.Id, cancellationToken);

            if (dispatch is null)
                return Result.Failure<DispatchActionResponse>(new Error(
                    "Dispatch.NotFound",
                    "Dispatch not found.",
                    StatusCodes.Status404NotFound));

            if (dispatch.Status != "Pending")
                return Result.Failure<DispatchActionResponse>(new Error(
                    "Dispatch.InvalidStatus",
                    $"Cannot accept — current status is {dispatch.Status}.",
                    StatusCodes.Status400BadRequest));

            dispatch.Status              = "OnTheWay";
            ambulance.AvailabilityStatus = "Busy";

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(new DispatchActionResponse(
                dispatch.Id, "OnTheWay", "Dispatch accepted. On the way.", false));
        }

        public async Task<Result<DispatchActionResponse>> RejectAsync(
            int dispatchId,
            string ambulanceEmail,
            CancellationToken cancellationToken = default)
        {
            var ambulance = await _context.Ambulances
                .FirstOrDefaultAsync(a => a.Email == ambulanceEmail, cancellationToken);

            if (ambulance is null)
                return Result.Failure<DispatchActionResponse>(new Error(
                    "Dispatch.AmbulanceNotFound",
                    "Ambulance not found.",
                    StatusCodes.Status404NotFound));

            var dispatch = await _context.EmergencyDispatches
                .Include(d => d.Patient)
                .FirstOrDefaultAsync(d =>
                    d.Id == dispatchId && d.AmbulanceId == ambulance.Id, cancellationToken);

            if (dispatch is null)
                return Result.Failure<DispatchActionResponse>(new Error(
                    "Dispatch.NotFound",
                    "Dispatch not found.",
                    StatusCodes.Status404NotFound));

            if (dispatch.Status != "Pending")
                return Result.Failure<DispatchActionResponse>(new Error(
                    "Dispatch.InvalidStatus",
                    $"Cannot reject — current status is {dispatch.Status}.",
                    StatusCodes.Status400BadRequest));

            // Free this ambulance
            dispatch.Status              = "Cancelled";
            ambulance.AvailabilityStatus = "Available";

            // Find next nearest available ambulance (Haversine simplified)
            double lat = dispatch.PatientLatitude;
            double lng = dispatch.PatientLongitude;

            var next = await _context.Ambulances
                .Where(a => a.AvailabilityStatus == "Available" &&
                            !a.IsDeleted &&
                            a.Id != ambulance.Id)
                .Select(a => new
                {
                    Ambulance = a,
                    Dist = Math.Sqrt(
                        Math.Pow((a.Latitude  ?? 0) - lat, 2) +
                        Math.Pow((a.Longitude ?? 0) - lng, 2))
                })
                .OrderBy(x => x.Dist)
                .Select(x => x.Ambulance)
                .FirstOrDefaultAsync(cancellationToken);

            bool reDispatched = false;

            if (next is not null)
            {
                var rows = await _context.Ambulances
                    .Where(a => a.Id == next.Id && a.AvailabilityStatus == "Available")
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(a => a.AvailabilityStatus, "Busy"),
                        cancellationToken);

                if (rows > 0)
                {
                    var newDispatch = new EmergencyDispatch
                    {
                        PatientId        = dispatch.PatientId,
                        AmbulanceId      = next.Id,
                        DispatchedAt     = DateTime.UtcNow,
                        Status           = "Pending",
                        PatientLatitude  = lat,
                        PatientLongitude = lng,
                        Notes            = (dispatch.Notes ?? "") + " [Re-dispatched]",
                    };

                    await _context.EmergencyDispatches.AddAsync(newDispatch, cancellationToken);
                    reDispatched = true;
                }
            }

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(new DispatchActionResponse(
                dispatch.Id,
                "Cancelled",
                reDispatched
                    ? "Rejected. Re-dispatched to next ambulance."
                    : "Rejected. No available ambulances.",
                reDispatched));
        }
    }
}
