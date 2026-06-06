
using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Contracts.VitalSigns
{
    public record VitalSignsResponse(
        int Id,
        int HeartRate,
        double OxygenSaturation,
        bool EmergencyStatus,
        DateTime TimeStamp,
        int SensorId,
        int PatientId,
        string PatientName,
        EmergencyDispatchResponse? AutoDispatch
    );
}