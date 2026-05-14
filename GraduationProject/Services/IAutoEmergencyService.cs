using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Services
{
    // NEW: service responsible for automatically triggering an emergency dispatch
    // when a patient's vital signs fall outside safe thresholds.
    // Called internally by VitalSignsService after saving a new reading.
    public interface IAutoEmergencyService
    {
        // Evaluates the saved vital signs reading.
        // If any value is critically abnormal AND the patient is not already
        // in an active emergency, it finds the nearest available ambulance
        // and creates an EmergencyDispatch record automatically.
        // Returns the created dispatch, or null if no emergency was triggered.
        Task<EmergencyDispatchResponse?> TryTriggerEmergencyAsync(
            int vitalSignsId,
            CancellationToken cancellationToken = default);
    }
}
