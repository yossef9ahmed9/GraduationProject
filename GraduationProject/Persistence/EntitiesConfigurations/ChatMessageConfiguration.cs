namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class ChatMessageConfiguration : IEntityTypeConfiguration<ChatMessage>
    {
        public void Configure(EntityTypeBuilder<ChatMessage> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.SenderEmail)
                .IsRequired()
                .HasMaxLength(150);

            builder.Property(x => x.SenderName)
                .HasMaxLength(100);

            builder.Property(x => x.ReceiverEmail)
                .IsRequired()
                .HasMaxLength(150);

            builder.Property(x => x.Content)
                .IsRequired()
                .HasMaxLength(2000);

            builder.Property(x => x.SentAt)
                .IsRequired();

            builder.HasIndex(x => new { x.SenderEmail, x.ReceiverEmail, x.SentAt })
                .HasDatabaseName("IX_ChatMessages_SenderEmail_ReceiverEmail_SentAt");
        }
    }
}
