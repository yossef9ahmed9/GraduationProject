using GraduationProject.Services.OCR;

namespace GraduationProject
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddProjectServices(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddControllers();

            services.AddAuthConfig(configuration);

            services.AddFluentValidationsConfig();
            services.AddSwaggerConfig();
            services.AddExceptionHandler<GlobalExceptionHandler>();
            services.AddProblemDetails();

            var connectionString = configuration.GetConnectionString("DefaultConnection") ??
                throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");

            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(connectionString));

            services.AddScoped<IPatientService, PatientService>();
            services.AddScoped<IAuthService, AuthService>();
            services.AddScoped<IDoctorService, DoctorService>();
            services.AddScoped<ISensorService, SensorService>();
            services.AddScoped<IVitalSignsService, VitalSignsService>();
            services.AddScoped<IFollowUpService, FollowUpService>();
            services.AddScoped<ILabService, LabService>();
            services.AddScoped<IMedicalTestService, MedicalTestService>();
            services.AddScoped<IFileService, FileService>();
            services.AddScoped<IOcrService, OcrService>();
            services.AddScoped<IAnalysisService, AnalysisService>();
            services.AddScoped<IEmergencyDispatchService, EmergencyDispatchService>();
            services.AddScoped<IAutoEmergencyService, AutoEmergencyService>();

            services.AddScoped<IFcmService, FcmService>();
            // NEW: AI heart-risk model
            services.AddScoped<IHeartRiskService, HeartRiskService>();
            services.AddHttpClient();

            services.Configure<EmailSettings>(configuration.GetSection(EmailSettings.SectionName));

            services.AddHostedService<RefreshTokenCleanupService>();
            services.AddScoped<IEmailService, EmailService>();
            services.AddScoped<INotificationService, NotificationService>();

            var mapingConfig = TypeAdapterConfig.GlobalSettings;
            mapingConfig.Scan(Assembly.GetExecutingAssembly());

            return services;
        }

        private static IServiceCollection AddSwaggerConfig(this IServiceCollection services)
        {
            services.AddEndpointsApiExplorer();
            services.AddSwaggerGen();
            return services;
        }

        private static IServiceCollection AddFluentValidationsConfig(this IServiceCollection services)
        {
            services
                .AddValidatorsFromAssembly(Assembly.GetExecutingAssembly())
                .AddFluentValidationAutoValidation();

            return services;
        }

        private static IServiceCollection AddAuthConfig(this IServiceCollection services, IConfiguration configuration)
        {
            services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.SectionName));
            services.AddSingleton<IJwtProvider, JwtProvider>();

            services.AddIdentity<ApplicationUser, IdentityRole>()
                .AddEntityFrameworkStores<AppDbContext>()
                .AddDefaultTokenProviders();

            var jwtOptions = configuration
                .GetSection(JwtOptions.SectionName)
                .Get<JwtOptions>()!;

            services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                options.DefaultChallengeScheme    = JwtBearerDefaults.AuthenticationScheme;
            })
            .AddJwtBearer(o =>
            {
                o.SaveToken = true;
                o.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    ValidateIssuer          = true,
                    ValidateAudience        = true,
                    ValidateLifetime        = true,
                    IssuerSigningKey        = new SymmetricSecurityKey(
                        Encoding.UTF8.GetBytes(jwtOptions.Key)),
                    ValidAudience = jwtOptions.Audience,
                    ValidIssuer   = jwtOptions.Issuer
                };
            });

            return services;
        }
    }
}
