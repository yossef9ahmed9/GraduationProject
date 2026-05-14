using GraduationProject.Contracts.Doctors;
using GraduationProject.Contracts.EmergencyDispatches;
using GraduationProject.Contracts.FollowUps;
using GraduationProject.Contracts.MedicalTests;
using GraduationProject.Contracts.Relatives;
using GraduationProject.Contracts.Sensors;
using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Mapping
{
    public class MappingConfigurations : IRegister
    {
        public void Register(TypeAdapterConfig config)
        {
            config.NewConfig<PatientRequest, Patient>();

            config.NewConfig<DoctorRequest, Doctor>();

            config.NewConfig<RelativeRequest, Relative>();

            config.NewConfig<SensorRequest, Sensor>();

            config.NewConfig<VitalSignsRequest, VitalSigns>()
                .Map(dest => dest.TimeStamp, src => DateTime.UtcNow);
                // PatientId and SensorId map automatically by name

            // NEW: map Patient navigation property to get PatientName in response.
            // NEW: AutoDispatch is always null from a direct Adapt call — it is
            //      populated manually by VitalSignsController after the emergency
            //      service runs. Mapster ignores null-mapped members by default,
            //      so we explicitly map it to null here as a no-op placeholder.
            config.NewConfig<VitalSigns, VitalSignsResponse>()
                .Map(dest => dest.PatientName, src => src.Patient != null
                    ? src.Patient.Name
                    : string.Empty)
                // NEW: AutoDispatch cannot be derived from the VitalSigns entity alone —
                // it is set by the controller after TryTriggerEmergencyAsync returns.
                // Mapping it to null here ensures Mapster doesn't throw on the unknown field.
                .Map(dest => dest.AutoDispatch, src => (EmergencyDispatchResponse?)null);

            config.NewConfig<FollowUpRequest, FollowUp>()
                .Map(dest => dest.LastUpdate, src => DateTime.UtcNow);

            config.NewConfig<MedicalTestRequest, MedicalTest>()
                .Map(dest => dest.Date, src => DateTime.UtcNow);
        }
    }
}
