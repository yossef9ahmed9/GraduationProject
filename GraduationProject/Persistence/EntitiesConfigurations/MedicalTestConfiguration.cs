
namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class MedicalTestConfiguration : IEntityTypeConfiguration<MedicalTest>
    {
        public void Configure(EntityTypeBuilder<MedicalTest> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.Name)
                .IsRequired()
                .HasMaxLength(100);

            builder.Property(x => x.Result)
                .HasMaxLength(500);

            builder.Property(x => x.Date)
                .IsRequired();

            builder.HasOne(x => x.Patient)
                .WithMany(x => x.MedicalTests)
                .HasForeignKey(x => x.PatientId);

            builder.HasOne(x => x.Lab)
                .WithMany(x => x.MedicalTests)
                .HasForeignKey(x => x.LabId);
        }
    }
}