using GraduationProject.Contracts.Ambulances;
using GraduationProject.Helpers;
using GraduationProject.Presistence;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Services
{
    public class AmbulanceService(AppDbContext context) : IAmbulanceService
    {
        private readonly AppDbContext _context = context;

        private static readonly string[] ValidStatuses =
            ["Available", "Busy", "NotAvailable"];

        public async Task<PagedResponse<AmbulanceResponse>> GetAllAsync(
            string? callerEmail, bool isAmbulanceRole,
            int pageNumber = 1, int pageSize = 20,
            CancellationToken cancellationToken = default)
        {
            var query = _context.Ambulances
                .AsNoTracking()
                .Where(a => !a.IsDeleted);

            if (isAmbulanceRole && callerEmail is not null)
                query = query.Where(a => a.Email == callerEmail);

            return await query
                .OrderBy(a => a.StationName)
                .Select(a => new AmbulanceResponse(
                    a.Id, a.Email, a.StationName, a.Phone, a.AvailabilityStatus,
                    a.LicensePlate, a.DriverName, a.DriverPhone,
                    a.Latitude, a.Longitude, a.LastLocationUpdate,
                    a.EmergencyDispatches.Count(d =>
                        d.Status != "Resolved" && d.Status != "Cancelled")))
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<IReadOnlyList<AmbulanceResponse>> GetAvailableAsync(
            CancellationToken cancellationToken = default)
        {
            return await _context.Ambulances
                .AsNoTracking()
                .Where(a => !a.IsDeleted && a.AvailabilityStatus == "Available")
                .OrderBy(a => a.StationName)
                .Select(a => new AmbulanceResponse(
                    a.Id, a.Email, a.StationName, a.Phone, a.AvailabilityStatus,
                    a.LicensePlate, a.DriverName, a.DriverPhone,
                    a.Latitude, a.Longitude, a.LastLocationUpdate, 0))
                .ToListAsync(cancellationToken);
        }

        public async Task<Result<AmbulanceResponse>> GetByIdAsync(
            int id, string? callerEmail, bool isAmbulanceRole,
            CancellationToken cancellationToken = default)
        {
            var ambulance = await _context.Ambulances
                .AsNoTracking()
                .Where(a => a.Id == id && !a.IsDeleted)
                .Select(a => new AmbulanceResponse(
                    a.Id, a.Email, a.StationName, a.Phone, a.AvailabilityStatus,
                    a.LicensePlate, a.DriverName, a.DriverPhone,
                    a.Latitude, a.Longitude, a.LastLocationUpdate,
                    a.EmergencyDispatches.Count(d =>
                        d.Status != "Resolved" && d.Status != "Cancelled")))
                .FirstOrDefaultAsync(cancellationToken);

            if (ambulance is null)
                return Result.Failure<AmbulanceResponse>(new Error(
                    "Ambulance.NotFound", "Ambulance not found.",
                    StatusCodes.Status404NotFound));

            if (isAmbulanceRole && callerEmail is not null &&
                !string.Equals(ambulance.Email, callerEmail, StringComparison.OrdinalIgnoreCase))
                return Result.Failure<AmbulanceResponse>(new Error(
                    "Ambulance.Forbidden", "Access denied.",
                    StatusCodes.Status403Forbidden));

            return Result.Success(ambulance);
        }

        public async Task<PagedResponse<AmbulanceDispatchSummary>> GetDispatchesAsync(
            int id, string? callerEmail, bool isAmbulanceRole,
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            if (isAmbulanceRole && callerEmail is not null)
            {
                var owns = await _context.Ambulances
                    .AnyAsync(a => a.Id == id && !a.IsDeleted && a.Email == callerEmail,
                        cancellationToken);

                if (!owns)
                    return new PagedResponse<AmbulanceDispatchSummary>(
                        [], pageNumber, pageSize, 0, 0, false, false);
            }

            return await _context.EmergencyDispatches
                .AsNoTracking()
                .Where(d => d.AmbulanceId == id)
                .OrderByDescending(d => d.DispatchedAt)
                .Select(d => new AmbulanceDispatchSummary(
                    d.Id, d.DispatchedAt, d.ArrivedAt, d.ResolvedAt,
                    d.Status, d.PatientId, d.Patient.Name, d.Notes))
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<Result> UpdateAvailabilityAsync(
            int id, string status, string callerEmail, bool isAmbulanceRole,
            CancellationToken cancellationToken = default)
        {
            if (!ValidStatuses.Contains(status))
                return Result.Failure(new Error(
                    "Ambulance.InvalidStatus",
                    $"Status must be one of: {string.Join(", ", ValidStatuses)}.",
                    StatusCodes.Status400BadRequest));

            var ambulance = await _context.Ambulances
                .FirstOrDefaultAsync(a => a.Id == id && !a.IsDeleted, cancellationToken);

            if (ambulance is null)
                return Result.Failure(new Error(
                    "Ambulance.NotFound", "Ambulance not found.",
                    StatusCodes.Status404NotFound));

            if (isAmbulanceRole &&
                !string.Equals(ambulance.Email, callerEmail, StringComparison.OrdinalIgnoreCase))
                return Result.Failure(new Error(
                    "Ambulance.Forbidden", "You can only update your own status.",
                    StatusCodes.Status403Forbidden));

            ambulance.AvailabilityStatus = status;
            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }

        public async Task<Result> SignInAsync(
            string callerEmail,
            CancellationToken cancellationToken = default)
        {
            var ambulance = await _context.Ambulances
                .FirstOrDefaultAsync(a => a.Email == callerEmail && !a.IsDeleted,
                    cancellationToken);

            if (ambulance is null)
                return Result.Failure(new Error(
                    "Ambulance.NotFound", "Ambulance not found.",
                    StatusCodes.Status404NotFound));

            ambulance.AvailabilityStatus = "Available";
            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }

        public async Task<Result> SignOutAsync(
            string callerEmail,
            CancellationToken cancellationToken = default)
        {
            var ambulance = await _context.Ambulances
                .FirstOrDefaultAsync(a => a.Email == callerEmail && !a.IsDeleted,
                    cancellationToken);

            if (ambulance is null)
                return Result.Failure(new Error(
                    "Ambulance.NotFound", "Ambulance not found.",
                    StatusCodes.Status404NotFound));

            var hasActive = await _context.EmergencyDispatches
                .AnyAsync(d => d.AmbulanceId == ambulance.Id &&
                               (d.Status == "Pending" ||
                                d.Status == "OnTheWay" ||
                                d.Status == "Arrived"),
                    cancellationToken);

            if (hasActive)
                return Result.Failure(new Error(
                    "Ambulance.ActiveDispatch",
                    "Cannot sign out while on an active dispatch.",
                    StatusCodes.Status409Conflict));

            ambulance.AvailabilityStatus = "NotAvailable";
            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }
    }
}
