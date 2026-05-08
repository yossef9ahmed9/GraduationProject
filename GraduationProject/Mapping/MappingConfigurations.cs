using GraduationProject.Contracts.Doctors;
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

            // NEW: map Patient navigation property to get PatientName in response
            config.NewConfig<VitalSigns, VitalSignsResponse>()
                .Map(dest => dest.PatientName, src => src.Patient != null
                    ? src.Patient.Name
                    : string.Empty);

            config.NewConfig<FollowUpRequest, FollowUp>()
                .Map(dest => dest.LastUpdate, src => DateTime.UtcNow);

            config.NewConfig<MedicalTestRequest, MedicalTest>()
                .Map(dest => dest.Date, src => DateTime.UtcNow);
        }
    }
}