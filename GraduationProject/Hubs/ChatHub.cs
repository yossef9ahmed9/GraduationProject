using Microsoft.AspNetCore.SignalR;

namespace GraduationProject.Hubs
{
    [Authorize]
    public class ChatHub(AppDbContext context) : Hub
    {
        private readonly AppDbContext _context = context;

        public async Task SendMessage(string receiverEmail, string content)
        {
            var senderEmail = Context.User?.FindFirst("email")?.Value
                           ?? Context.User?.FindFirst(ClaimTypes.Email)?.Value
                           ?? "unknown";

            var senderName = Context.User?.FindFirst("name")?.Value
                          ?? Context.User?.Identity?.Name
                          ?? senderEmail;

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
        }

        public override async Task OnConnectedAsync()
        {
            var email = Context.User?.FindFirst("email")?.Value
                     ?? Context.User?.FindFirst(ClaimTypes.Email)?.Value;

            if (!string.IsNullOrEmpty(email))
                await Groups.AddToGroupAsync(Context.ConnectionId, email);

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var email = Context.User?.FindFirst("email")?.Value
                     ?? Context.User?.FindFirst(ClaimTypes.Email)?.Value;

            if (!string.IsNullOrEmpty(email))
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, email);

            await base.OnDisconnectedAsync(exception);
        }
    }
}
