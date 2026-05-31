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

            // FIXED: AutoDispatch is always null from a direct Adapt call.
            // VitalSignsService now uses a `with` expression after the Adapt to
            // replace it with the real dispatch value, so mapping it to null here
            // is correct and intentional.
            config.NewConfig<VitalSigns, VitalSignsResponse>()
                .Map(dest => dest.PatientName, src => src.Patient != null
                    ? src.Patient.Name
                    : string.Empty)
                .Map(dest => dest.AutoDispatch, src => (EmergencyDispatchResponse?)null);

            config.NewConfig<FollowUpRequest, FollowUp>()
                .Map(dest => dest.LastUpdate, src => DateTime.UtcNow);

            config.NewConfig<MedicalTestRequest, MedicalTest>()
                .Map(dest => dest.Date, src => DateTime.UtcNow);
        }
    }
}
