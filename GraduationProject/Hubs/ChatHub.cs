using Microsoft.AspNetCore.SignalR;

namespace GraduationProject.Hubs
{
    [Authorize]
    public class ChatHub(AppDbContext context, IFcmService fcmService, ILogger<ChatHub> logger, UserManager<ApplicationUser> userManager) : Hub
    {
        private readonly AppDbContext _context    = context;
        private readonly IFcmService  _fcmService = fcmService;
        private readonly ILogger<ChatHub> _logger = logger;
        private readonly UserManager<ApplicationUser> _userManager = userManager;

        // Track connected emails — shared across all hub instances via static ConcurrentDictionary
        private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, int>
            _onlineUsers = new(StringComparer.OrdinalIgnoreCase);

        public async Task SendMessage(string receiverEmail, string content)
        {
            var senderEmail = Context.User?.FindFirst("email")?.Value
                           ?? Context.User?.FindFirst(ClaimTypes.Email)?.Value
                           ?? "unknown";

            // Look up real name from DB — more reliable than JWT claim
            var senderName = await GetDisplayNameAsync(senderEmail);

            var msg = new ChatMessage
            {
                SenderEmail   = senderEmail,
                SenderName    = senderName,
                ReceiverEmail = receiverEmail,
                Content       = content,
                SentAt        = DateTime.UtcNow,
            };

            _context.ChatMessages.Add(msg);
            await _context.SaveChangesAsync();

            var payload = new
            {
                id            = msg.Id,
                senderEmail   = msg.SenderEmail,
                senderName    = msg.SenderName,
                receiverEmail = msg.ReceiverEmail,
                content       = msg.Content,
                sentAt        = msg.SentAt,
            };

            await Clients.Group(receiverEmail).SendAsync("ReceiveMessage", payload);
            await Clients.Caller.SendAsync("ReceiveMessage", payload);

            // Send FCM push to receiver only (not the sender)
            await SendChatPushAsync(receiverEmail, senderEmail, senderName, content);
        }

        // ── FCM fallback: look up receiver's FCM token and send push ─────────
        private async Task SendChatPushAsync(string receiverEmail, string senderEmail, string senderName, string content)
        {
            // Don't send push to yourself
            if (string.Equals(receiverEmail, senderEmail, StringComparison.OrdinalIgnoreCase))
                return;

            string? fcmToken = null;

            var patient = await _context.Patients
                .AsNoTracking()
                .Where(p => p.Email == receiverEmail)
                .Select(p => p.FcmToken)
                .FirstOrDefaultAsync();
            fcmToken ??= patient;

            if (fcmToken == null)
            {
                var doctor = await _context.Doctors
                    .AsNoTracking()
                    .Where(d => d.Email == receiverEmail)
                    .Select(d => d.FcmToken)
                    .FirstOrDefaultAsync();
                fcmToken ??= doctor;
            }

            if (fcmToken == null)
            {
                var relative = await _context.Relatives
                    .AsNoTracking()
                    .Where(r => r.Email == receiverEmail)
                    .Select(r => r.FcmToken)
                    .FirstOrDefaultAsync();
                fcmToken ??= relative;
            }

            _logger.LogInformation(
                "[ChatHub] FCM lookup for {Email} → token={Token}",
                receiverEmail,
                fcmToken != null ? fcmToken[..15] + "..." : "NULL");

            if (!string.IsNullOrEmpty(fcmToken))
            {
                await _fcmService.SendPushAsync(
                    fcmToken,
                    senderName,
                    content,
                    new Dictionary<string, string>
                    {
                        ["type"]        = "chat",
                        ["senderEmail"] = senderEmail,
                        ["senderName"]  = senderName,
                    });
            }
            else
            {
                _logger.LogWarning(
                    "[ChatHub] No FCM token found for {Email} — push skipped", receiverEmail);
            }
        }

        // ── Look up display name — DB first, fallback to UserManager ────
        private async Task<string> GetDisplayNameAsync(string email)
        {
            // Patient
            var patient = await _context.Patients
                .AsNoTracking()
                .Where(p => p.Email == email)
                .Select(p => p.Name)
                .FirstOrDefaultAsync();
            if (patient != null) return patient;

            // Doctor
            var doctor = await _context.Doctors
                .AsNoTracking()
                .Where(d => d.Email == email)
                .Select(d => d.Name)
                .FirstOrDefaultAsync();
            if (doctor != null) return doctor;

            // Relative
            var relative = await _context.Relatives
                .AsNoTracking()
                .Where(r => r.Email == email)
                .Select(r => r.Name)
                .FirstOrDefaultAsync();
            if (relative != null) return relative;

            // Lab / Ambulance — look up via UserManager
            var appUser = await _userManager.FindByEmailAsync(email);
            if (appUser != null && !string.IsNullOrEmpty(appUser.FullName))
                return appUser.FullName;

            return email;
        }

        public override async Task OnConnectedAsync()
        {
            var email = Context.User?.FindFirst("email")?.Value
                     ?? Context.User?.FindFirst(ClaimTypes.Email)?.Value;

            if (!string.IsNullOrEmpty(email))
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, email);
                _onlineUsers.AddOrUpdate(email, 1, (_, count) => count + 1);
            }

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var email = Context.User?.FindFirst("email")?.Value
                     ?? Context.User?.FindFirst(ClaimTypes.Email)?.Value;

            if (!string.IsNullOrEmpty(email))
            {
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, email);
                _onlineUsers.AddOrUpdate(email, 0, (_, count) => Math.Max(0, count - 1));
                if (_onlineUsers.TryGetValue(email, out var remaining) && remaining == 0)
                    _onlineUsers.TryRemove(email, out _);
            }

            await base.OnDisconnectedAsync(exception);
        }
    }
}
