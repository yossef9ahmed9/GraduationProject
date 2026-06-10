// ════════════════════════════════════════════════════════════════
// FCM Push Notifications
//
// HOW TO SET UP:
// 1. Go to https://console.firebase.google.com
// 2. Create project → Add Android app → package: com.example.meditrack
// 3. Download google-services.json → put it in android/app/
// 4. Go to Project Settings → Service accounts → Generate new private key
// 5. Save the JSON file as firebase-adminsdk.json in the project root
// 6. In appsettings.json add:
//    "Firebase": { "CredentialPath": "firebase-adminsdk.json" }
//
// NUGET PACKAGE REQUIRED:
//   FirebaseAdmin (by Google)
//   Install-Package FirebaseAdmin
// ════════════════════════════════════════════════════════════════

using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using GraduationProject.Contracts.Notifications;
using GraduationProject.Presistence;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Services
{
    // ── Interface extension ───────────────────────────────────────────────────
    // Add this method to INotificationService:
    //   Task SendPushAsync(string fcmToken, string title, string body,
    //       Dictionary<string,string>? data = null, CancellationToken ct = default);
    //   Task RegisterFcmTokenAsync(string userId, string fcmToken, CancellationToken ct = default);

    // ── FCM Service ───────────────────────────────────────────────────────────
    public class FcmService(
        AppDbContext context,
        IConfiguration configuration,
        ILogger<FcmService> logger) : IFcmService
    {
        private readonly AppDbContext    _context       = context;
        private readonly IConfiguration  _config        = configuration;
        private readonly ILogger<FcmService> _logger    = logger;
        private static bool _initialized = false;
        private static readonly object _lock = new();

        private void EnsureInitialized()
        {
            if (_initialized) return;
            lock (_lock)
            {
                if (_initialized) return;

                // Priority: Environment Variable → appsettings.json
                var credPath = Environment.GetEnvironmentVariable("FIREBASE_KEY_PATH")
                    ?? _config["Firebase:CredentialPath"]
                    ?? "firebase-adminsdk.json";

                if (!File.Exists(credPath))
                {
                    _logger.LogWarning(
                        "Firebase credential file not found at '{Path}'. " +
                        "Push notifications will be skipped.", credPath);
                    return;
                }

                FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromFile(credPath)
                });
                _initialized = true;
            }
        }

        // ── Send push to a single FCM token ───────────────────────────────────
        public async Task SendPushAsync(
            string fcmToken,
            string title,
            string body,
            Dictionary<string, string>? data = null,
            CancellationToken cancellationToken = default)
        {
            EnsureInitialized();
            if (!_initialized) return;

            try
            {
                var message = new Message
                {
                    Token = fcmToken,
                    Notification = new Notification { Title = title, Body = body },
                    Data = data ?? new Dictionary<string, string>(),
                    Android = new AndroidConfig
                    {
                        Priority = Priority.High,
                        Notification = new AndroidNotification
                        {
                            Sound = "default",
                            ChannelId = "meditrack_alerts"
                        }
                    }
                };

                var response = await FirebaseMessaging.DefaultInstance
                    .SendAsync(message, cancellationToken);

                _logger.LogInformation("FCM sent: {MessageId}", response);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "FCM send failed for token {Token}", fcmToken[..10]);
            }
        }

        // ── Send emergency push to patient's relatives, doctors, and dispatched ambulances ──
        public async Task SendEmergencyPushAsync(
            int patientId,
            string patientName,
            string notes,
            CancellationToken cancellationToken = default)
        {
            // Get FCM tokens for all relatives linked to this patient via approved requests
            var relativeFcmTokens = await _context.Relatives
                .AsNoTracking()
                .Where(r => r.PatientRequests.Any(req =>
                    req.PatientId == patientId && req.Status == "Approved")
                    && r.FcmToken != null)
                .Select(r => r.FcmToken!)
                .ToListAsync(cancellationToken);

            // Get FCM tokens for doctors linked via follow-ups
            var doctorFcmTokens = await _context.FollowUps
                .AsNoTracking()
                .Where(f => f.PatientId == patientId)
                .Select(f => f.Doctor.FcmToken)
                .Where(t => t != null)
                .Distinct()
                .ToListAsync(cancellationToken);

            // Send to relatives + doctors with type "emergency"
            var relDocTokens = relativeFcmTokens
                .Concat(doctorFcmTokens!)
                .Distinct()
                .ToList();

            var relDocTasks = relDocTokens.Select(token => SendPushAsync(
                token,
                $"🚨 Emergency — {patientName}",
                notes,
                new Dictionary<string, string>
                {
                    ["patientId"] = patientId.ToString(),
                    ["type"]      = "emergency"
                },
                cancellationToken));

            await Task.WhenAll(relDocTasks);

            // Get all Pending dispatches for this patient and send to each ambulance
            var ambulanceDispatches = await _context.EmergencyDispatches
                .AsNoTracking()
                .Where(d => d.PatientId == patientId && d.Status == "Pending" && d.Ambulance.FcmToken != null)
                .Select(d => new { d.Id, d.Ambulance.FcmToken })
                .ToListAsync(cancellationToken);

            var ambTasks = ambulanceDispatches.Select(d => SendPushAsync(
                d.FcmToken!,
                $"🚨 New Emergency Dispatch",
                $"Patient: {patientName} — {notes}",
                new Dictionary<string, string>
                {
                    ["patientId"]  = patientId.ToString(),
                    ["dispatchId"] = d.Id.ToString(),
                    ["type"]       = "dispatch"
                },
                cancellationToken));

            await Task.WhenAll(ambTasks);
        }

        // ── Send normal vitals push to doctors and relatives ─────────────────
        public async Task SendNormalVitalsPushAsync(
            int patientId,
            string patientName,
            string details,
            CancellationToken cancellationToken = default)
        {
            var doctorTokens = await _context.FollowUps
                .AsNoTracking()
                .Where(f => f.PatientId == patientId && f.Doctor.FcmToken != null)
                .Select(f => f.Doctor.FcmToken!)
                .Distinct()
                .ToListAsync(cancellationToken);

            var relativeTokens = await _context.Relatives
                .AsNoTracking()
                .Where(r => r.PatientRequests.Any(req =>
                    req.PatientId == patientId && req.Status == "Approved")
                    && r.FcmToken != null)
                .Select(r => r.FcmToken!)
                .Distinct()
                .ToListAsync(cancellationToken);

            var allTokens = doctorTokens.Concat(relativeTokens).Distinct();
            var tasks = allTokens.Select(token => SendPushAsync(
                token,
                $"✅ {patientName} — Vitals Normal",
                $"Emergency resolved. {details}",
                new Dictionary<string, string>
                {
                    ["patientId"] = patientId.ToString(),
                    ["type"]      = "normal_vitals",
                },
                cancellationToken));

            await Task.WhenAll(tasks);
        }

        // ── Save FCM token for a user ─────────────────────────────────────────
        public async Task RegisterFcmTokenAsync(
            string userId,
            string fcmToken,
            CancellationToken cancellationToken = default)
        {
            // Try patient first
            var patient = await _context.Patients
                .FirstOrDefaultAsync(p => p.Email == userId, cancellationToken);
            if (patient is not null)
            {
                patient.FcmToken = fcmToken;
                await _context.SaveChangesAsync(cancellationToken);
                return;
            }

            // Try relative
            var relative = await _context.Relatives
                .FirstOrDefaultAsync(r => r.Email == userId, cancellationToken);
            if (relative is not null)
            {
                relative.FcmToken = fcmToken;
                await _context.SaveChangesAsync(cancellationToken);
                return;
            }

            // Try doctor
            var doctor = await _context.Doctors
                .FirstOrDefaultAsync(d => d.Email == userId, cancellationToken);
            if (doctor is not null)
            {
                doctor.FcmToken = fcmToken;
                await _context.SaveChangesAsync(cancellationToken);
                return;
            }

            // Try ambulance
            var ambulance = await _context.Ambulances
                .FirstOrDefaultAsync(a => a.Email == userId, cancellationToken);
            if (ambulance is not null)
            {
                ambulance.FcmToken = fcmToken;
                await _context.SaveChangesAsync(cancellationToken);
            }
        }
    }

  
}

// ════════════════════════════════════════════════════════════════
// ALSO NEEDED — add FcmToken property to these entities:
//
// Patient.cs:
//   public string? FcmToken { get; set; }
//
// Relative.cs:
//   public string? FcmToken { get; set; }
//
// Doctor.cs:
//   public string? FcmToken { get; set; }
//
// Register in Program.cs:
//   builder.Services.AddSingleton<IFcmService, FcmService>();
//
// Add endpoint in AuthController or new FcmController:
//   POST /api/fcm/register  { "userId": "email", "fcmToken": "..." }
//
// Call in AutoEmergencyService after dispatch:
//   await _fcmService.SendEmergencyPushAsync(patient.Id, patient.Name, notes, ct);
//
// Run migration after adding FcmToken columns:
//   Add-Migration AddFcmTokens
//   Update-Database
// ════════════════════════════════════════════════════════════════
