namespace GraduationProject.Contracts.DispatchRequests
{
    public record ActiveDispatchResponse(
        int      Id,
        string   Status,
        DateTime DispatchedAt,
        double   PatientLatitude,
        double   PatientLongitude,
        string?  Notes,
        int      PatientId,
        string   PatientName,
        string   PatientPhone
    );

    public record DispatchActionResponse(
        int    DispatchId,
        string NewStatus,
        string Message,
        bool   ReDispatched
    );
}
