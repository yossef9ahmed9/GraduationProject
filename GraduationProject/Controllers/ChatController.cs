namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class ChatController(AppDbContext context) : ControllerBase
    {
        private readonly AppDbContext _context = context;

        [HttpGet("history/{otherEmail}")]
        public async Task<IActionResult> GetHistory(
            string otherEmail,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize = 50,
            CancellationToken cancellationToken = default)
        {
            var myEmail = User.FindFirst("email")?.Value
                       ?? User.FindFirst(ClaimTypes.Email)?.Value ?? "";

            var messages = await _context.ChatMessages
                .AsNoTracking()
                .Where(m =>
                    (m.SenderEmail == myEmail && m.ReceiverEmail == otherEmail && !m.DeletedBySender) ||
                    (m.SenderEmail == otherEmail && m.ReceiverEmail == myEmail && !m.DeletedByReceiver))
                .OrderByDescending(m => m.SentAt)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .Select(m => new
                {
                    m.Id,
                    m.SenderEmail,
                    m.SenderName,
                    m.ReceiverEmail,
                    m.Content,
                    m.SentAt,
                    m.IsRead,
                    isMine = m.SenderEmail == myEmail,
                })
                .ToListAsync(cancellationToken);

            await _context.ChatMessages
                .Where(m => m.SenderEmail == otherEmail &&
                            m.ReceiverEmail == myEmail &&
                            !m.IsRead)
                .ExecuteUpdateAsync(s => s.SetProperty(m => m.IsRead, true),
                    cancellationToken);

            return Ok(messages.OrderBy(m => m.SentAt));
        }

        [HttpGet("conversations")]
        public async Task<IActionResult> GetConversations(
            CancellationToken cancellationToken = default)
        {
            var myEmail = User.FindFirst("email")?.Value
                       ?? User.FindFirst(ClaimTypes.Email)?.Value ?? "";

            var sent = await _context.ChatMessages
                .AsNoTracking()
                .Where(m => m.SenderEmail == myEmail || m.ReceiverEmail == myEmail)
                .OrderByDescending(m => m.SentAt)
                .ToListAsync(cancellationToken);

            var conversations = sent
                .GroupBy(m => m.SenderEmail == myEmail ? m.ReceiverEmail : m.SenderEmail)
                .Select(g =>
                {
                    var last = g.First();
                    var unread = g.Count(m => m.ReceiverEmail == myEmail && !m.IsRead);
                    return new
                    {
                        otherEmail = g.Key,
                        otherName = last.SenderEmail == myEmail ? last.ReceiverEmail : last.SenderName,
                        lastMessage = last.Content,
                        lastSentAt = last.SentAt,
                        unreadCount = unread,
                    };
                })
                .OrderByDescending(c => c.lastSentAt)
                .ToList();

            return Ok(conversations);
        }

        [HttpGet("unread-count")]
        public async Task<IActionResult> GetUnreadCount(
            CancellationToken cancellationToken = default)
        {
            var myEmail = User.FindFirst("email")?.Value
                       ?? User.FindFirst(ClaimTypes.Email)?.Value ?? "";

            var count = await _context.ChatMessages
                .AsNoTracking()
                .CountAsync(m => m.ReceiverEmail == myEmail && !m.IsRead, cancellationToken);

            return Ok(new { unreadCount = count });
        }

        // DELETE /api/chat/message/{id}  — delete for me only (soft delete per user)
        [HttpDelete("message/{id}")]
        public async Task<IActionResult> DeleteMessage(
            int id,
            CancellationToken cancellationToken = default)
        {
            var myEmail = User.FindFirst("email")?.Value
                       ?? User.FindFirst(ClaimTypes.Email)?.Value ?? "";

            var msg = await _context.ChatMessages
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(m => m.Id == id, cancellationToken);

            if (msg is null) return NotFound();

            if (msg.SenderEmail == myEmail)
                msg.DeletedBySender = true;
            else if (msg.ReceiverEmail == myEmail)
                msg.DeletedByReceiver = true;
            else
                return Forbid();

            await _context.SaveChangesAsync(cancellationToken);
            return NoContent();
        }

        // DELETE /api/chat/message/{id}/all  — delete for everyone
        [HttpDelete("message/{id}/all")]
        public async Task<IActionResult> DeleteMessageForEveryone(
            int id,
            CancellationToken cancellationToken = default)
        {
            var myEmail = User.FindFirst("email")?.Value
                       ?? User.FindFirst(ClaimTypes.Email)?.Value ?? "";

            var msg = await _context.ChatMessages
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(m => m.Id == id, cancellationToken);

            if (msg is null) return NotFound();
            if (msg.SenderEmail != myEmail) return Forbid();

            msg.DeletedBySender   = true;
            msg.DeletedByReceiver = true;
            msg.Content           = "🗑️ This message was deleted";
            await _context.SaveChangesAsync(cancellationToken);
            return NoContent();
        }

        // DELETE /api/chat/conversation/{otherEmail}  — clear for me only
        [HttpDelete("conversation/{otherEmail}")]
        public async Task<IActionResult> ClearConversation(
            string otherEmail,
            CancellationToken cancellationToken = default)
        {
            var myEmail = User.FindFirst("email")?.Value
                       ?? User.FindFirst(ClaimTypes.Email)?.Value ?? "";

            await _context.ChatMessages
                .IgnoreQueryFilters()
                .Where(m => m.SenderEmail == myEmail && m.ReceiverEmail == otherEmail)
                .ExecuteUpdateAsync(s => s.SetProperty(m => m.DeletedBySender, true), cancellationToken);

            await _context.ChatMessages
                .IgnoreQueryFilters()
                .Where(m => m.SenderEmail == otherEmail && m.ReceiverEmail == myEmail)
                .ExecuteUpdateAsync(s => s.SetProperty(m => m.DeletedByReceiver, true), cancellationToken);

            return NoContent();
        }

        // DELETE /api/chat/conversation/{otherEmail}/all  — clear for everyone
        [HttpDelete("conversation/{otherEmail}/all")]
        public async Task<IActionResult> ClearConversationForEveryone(
            string otherEmail,
            CancellationToken cancellationToken = default)
        {
            var myEmail = User.FindFirst("email")?.Value
                       ?? User.FindFirst(ClaimTypes.Email)?.Value ?? "";

            await _context.ChatMessages
                .IgnoreQueryFilters()
                .Where(m =>
                    (m.SenderEmail == myEmail && m.ReceiverEmail == otherEmail) ||
                    (m.SenderEmail == otherEmail && m.ReceiverEmail == myEmail))
                .ExecuteUpdateAsync(s => s
                    .SetProperty(m => m.DeletedBySender,   true)
                    .SetProperty(m => m.DeletedByReceiver, true)
                    .SetProperty(m => m.IsDeleted,         true)
                    .SetProperty(m => m.DeletedAtUtc,      DateTime.UtcNow),
                    cancellationToken);

            return NoContent();
        }
    }
}
