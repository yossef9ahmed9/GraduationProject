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

            config.NewConfig<FollowUpRequest, FollowUp>()
                .Map(dest => dest.LastUpdate, src => DateTime.UtcNow);

            config.NewConfig<MedicalTestRequest, MedicalTest>()
                .Map(dest => dest.Date, src => DateTime.UtcNow);
        }
    }
}