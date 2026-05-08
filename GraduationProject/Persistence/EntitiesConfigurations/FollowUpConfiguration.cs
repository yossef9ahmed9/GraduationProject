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

            // NOTE: no OnDelete here — handled globally/explicitly in AppDbContext
            builder.HasOne(x => x.Patient)
                .WithMany(x => x.FollowUps)
                .HasForeignKey(x => x.PatientId);

            // Doctor → FollowUp is Restrict (global rule)
            // meaning you cannot delete a doctor who still has follow-ups
            builder.HasOne(x => x.Doctor)
                .WithMany(x => x.FollowUps)
                .HasForeignKey(x => x.DoctorId);
        }
    }
}