# Send Message (`send_message.sh` / `send_message.ps1`)

**Usage:**
```bash
./send_message.sh [taskId] [message]
```

**Description:**
Sends a text instruction or message to an active Jules task. This is the primary method to reply to Jules when it asks a question or requires user feedback.

**Behavior:**
- Calls `POST https://jules.googleapis.com/v1alpha/sessions/{taskId}:sendMessage`.
- Returns a success confirmation.

**Requires:**
- `JULES_API_KEY` (configured via `setup.sh`)