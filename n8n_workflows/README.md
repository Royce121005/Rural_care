# n8n Workflows for RuralCare

This directory contains n8n workflow automation files for the RuralCare healthcare platform.

## Available Workflows

### 1. Telegram Advanced Bot (`telegram_advanced_bot.json`)

A comprehensive Telegram bot integration providing patients with:

**Features:**
- 🔗 Account linking with phone verification
- 💊 Active prescription tracking & reminders
- 📅 Consultation scheduling & status
- 📸 Medicine image identification (OCR + AI)
- 🎤 Voice message support with medical chatbot
- 💬 Contextual chat using patient medical history
- 📊 Personal health dashboard

**Architecture:**
- 50+ nodes including triggers, HTTP requests, data transformation
- Telegram webhook/polling triggers for real-time messaging
- RESTful integration with Django backend APIs
- Multi-path routing based on user commands
- Error handling and fallback messages

**Commands:**
```
/start - Welcome message and account status
/link <phone> - Link Telegram to RuralCare account
/prescriptions - View active prescriptions
/consultations - View upcoming/past consultations
/dashboard - Personal health summary
/help - Command reference
```

**Triggers:**
- Text messages (commands & chat)
- Photo messages (medicine identification)
- Voice messages (voice-to-text + chatbot)

## Workflow Structure

```
telegram_advanced_bot.json
├── Triggers
│   ├── Telegram Message (Text)
│   ├── Telegram Photo (Images)
│   └── Telegram Voice (Audio)
│
├── User Verification
│   ├── Verify User API Call
│   └── Link Status Check
│
├── Command Router (Switch Node)
│   ├── /start → Welcome Message
│   ├── /link → Account Linking Flow
│   ├── /prescriptions → Get Prescriptions API
│   ├── /consultations → Get Consultations API
│   ├── /dashboard → User Data Summary
│   └── /help → Help Message
│
├── Medicine Identification Pipeline
│   ├── Download Photo from Telegram
│   ├── Upload to Django API
│   ├── Get Identification Result
│   └── Format & Send Response
│
├── Voice Processing Pipeline
│   ├── Download Voice from Telegram
│   ├── Transcribe Audio (Groq/OpenAI)
│   ├── Query Medical Chatbot
│   └── Send Text Response
│
└── Contextual Chat
    ├── Get User Medical Context
    ├── Build Personalized Prompt
    ├── Query Chatbot with Context
    └── Send Response with Markdown
```

## Installation

1. **Import Workflow:**
   ```
   n8n → Workflows → Import from File → Select telegram_advanced_bot.json
   ```

2. **Configure Credentials:**
   - Telegram Bot API (from @BotFather)
   - Django API Authentication (Header Auth)

3. **Set Environment Variables:**
   ```
   DJANGO_BASE_URL=https://your-domain.com
   PORTAL_URL=https://portal.your-domain.com
   TELEGRAM_BOT_TOKEN=your-bot-token
   ```

4. **Update API Endpoints:**
   - Replace `{{$env.DJANGO_BASE_URL}}` with actual URLs
   - Configure all HTTP Request nodes

5. **Activate Workflow:**
   - Toggle "Active" in n8n editor
   - Test with Telegram bot

## Required Django APIs

The workflow requires these Django endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/telegram/verify-user/` | GET | Verify Telegram user |
| `/api/telegram/get-user-data/` | GET | Fetch user profile |
| `/api/telegram/link-account/` | POST | Link accounts |
| `/api/telegram/get-prescriptions/` | GET | Active prescriptions |
| `/api/telegram/get-consultations/` | GET | Consultations |
| `/api/telegram/chat/` | POST | Medical chatbot |
| `/api/telegram/identify-medicine/` | POST | Medicine identification |

## Testing

Test each feature:

```bash
# Start conversation
/start

# Link account
/link +1234567890

# View prescriptions
/prescriptions

# Send medicine photo
[Upload medicine image]

# Send voice message
[Record voice: "What are my medications?"]

# Chat
"I have a headache, what should I do?"
```

## Monitoring

**View Executions:**
- n8n Dashboard → Executions
- See all workflow runs with input/output data

**Common Metrics:**
- Messages processed per day
- Command usage frequency
- API response times
- Error rates per node

## Troubleshooting

**Workflow not triggering:**
- Check workflow is Active
- Verify Telegram credentials
- Test bot with BotFather

**API errors:**
- Verify `DJANGO_BASE_URL` is correct
- Check Django server is running
- Test endpoints with curl

**Medicine identification fails:**
- Check image file size (< 10MB)
- Verify Groq API credentials in Django
- Review Django logs

**Voice messages not working:**
- Check Telegram file download permissions
- Verify audio transcription service

## Performance Optimization

**For high traffic:**

1. **Caching**: Cache user verification checks (Redis)
2. **Queue**: Use Celery for heavy tasks (image analysis)
3. **Webhooks**: Use webhooks instead of polling
4. **Database**: Connection pooling for API calls
5. **CDN**: Serve media files from CDN

## Security

**Best Practices:**

- ✅ Use HTTPS for all API calls
- ✅ Implement API key authentication
- ✅ Rate limit API endpoints
- ✅ Validate file uploads (type, size)
- ✅ Sanitize user inputs
- ✅ Log all access attempts
- ✅ Rotate credentials periodically

## Extending the Workflow

**Add new commands:**

1. Add case to Switch node (Command Router)
2. Create new HTTP Request nodes for APIs
3. Format response message
4. Connect to Telegram Send node

**Add new triggers:**

1. Add new Telegram Trigger node
2. Configure trigger type (document, location, etc.)
3. Process data with Code nodes
4. Respond to user

**Integrate new features:**

1. Create Django API endpoint
2. Add HTTP Request node in workflow
3. Transform data with Code node
4. Format response

## Version History

**v1.0.0** (Current)
- ✅ Account linking with phone verification
- ✅ Prescription tracking
- ✅ Consultation scheduling
- ✅ Medicine identification
- ✅ Voice message support
- ✅ Contextual medical chatbot
- ✅ Personal health dashboard

## Contributing

To modify workflows:

1. Import JSON into n8n
2. Make changes in visual editor
3. Export workflow
4. Replace JSON file in this directory
5. Update documentation

## Support

**Documentation:**
- [Full Setup Guide](../TELEGRAM_BOT_SETUP.md)
- [n8n Documentation](https://docs.n8n.io)
- [Telegram Bot API](https://core.telegram.org/bots/api)

**Issues:**
- Check execution logs in n8n
- Review Django server logs
- Test APIs individually

---

**Quick Start:** See [TELEGRAM_BOT_SETUP.md](../TELEGRAM_BOT_SETUP.md) for detailed setup instructions.
