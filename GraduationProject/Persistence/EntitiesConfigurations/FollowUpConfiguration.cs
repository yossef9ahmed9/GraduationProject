namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class FollowUpConfiguration : IEntityTypeConfiguration<FollowUp>
    {
        public void Configure(EntityTypeBuilder<FollowUp> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.Diagnosis)
                .HasMaxLength(500);

            builder.Property(x => x.TreatmentPlan)
                .HasMaxLength(500);

            builder.Property(x => x.Notes)
                .HasMaxLength(500);

            builder.Property(x => x.LastUpdate)
                .IsRequired();

            builder.HasOne(x => x.Patient)
                .WithMany(x => x.FollowUps)
                .HasForeignKey(x => x.PatientId);

            builder.HasOne(x => x.Doctor)
                .WithMany(x => x.FollowUps)
                .HasForeignKey(x => x.DoctorId);
        }
    }
}
