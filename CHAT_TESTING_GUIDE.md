# Chat History Testing Guide

## Quick Test Instructions

To verify that chat history is working correctly, follow these steps:

### Test 1: Basic Message Storage
1. Open the Buddy app
2. Send a message: "Hello, my name is [YourName]"
3. Wait for response
4. Send another message: "What is my name?"
5. **Expected Result**: Buddy should remember your name from the previous message

### Test 2: Context Preservation
1. Send: "Create a simple calculator app"
2. Wait for response
3. Send: "Add a square root function to it"
4. **Expected Result**: Buddy should understand "it" refers to the calculator and modify it

### Test 3: Conversation Persistence
1. Have a conversation with multiple messages
2. Start a new conversation (tap the new chat button)
3. Go back to the previous conversation
4. **Expected Result**: All messages should still be there

### Test 4: App Restart
1. Have a conversation
2. Close the app completely
3. Reopen the app
4. **Expected Result**: Previous conversation should be restored

## Debug Commands (for developers)

If issues persist, add these debug calls to check the internal state:

```dart
// In buddy_screen.dart or any widget
await BuddyService.debugChatHistory();
```

## Expected Debug Output

When the app starts, you should see logs like:
```
🚀 Initializing BuddyService...
📚 Loaded X messages from chat database
✅ BuddyService initialized with X messages
```

When sending messages, you should see:
```
💾 Saved user message: Hello, my name is...
💾 Saved assistant message: Nice to meet you...
```

## Common Issues and Solutions

### Issue 1: Messages not persisting
**Symptom**: Messages disappear when app restarts
**Solution**: Check that `BuddyService.initialize()` is called in `main.dart`

### Issue 2: Context not maintained
**Symptom**: Buddy doesn't remember previous parts of conversation
**Solution**: Verify that chat history is being sent to backend correctly

### Issue 3: Conversations mixing up
**Symptom**: Messages appear in wrong conversations
**Solution**: Check conversation switching logic in `BuddyChatDatabase`

## Backend Integration Verification

The backend should receive requests with proper chat history:
```json
{
  "prompt": "What is my name?",
  "chat_history": [
    {"role": "user", "content": "My name is John"},
    {"role": "assistant", "content": "Nice to meet you, John!"}
  ],
  "is_task_continuation": true,
  "recent_context": "User introduced themselves as John",
  "session_id": "unique-session-id"
}
```

If any test fails, the issue is likely in:
1. Message saving logic
2. Message loading logic  
3. Context detection
4. Backend integration

## Troubleshooting Steps

1. **Clear app data** and test fresh installation
2. **Check logs** for initialization and save messages
3. **Verify database state** using debug methods
4. **Test backend independently** with manual requests
5. **Check conversation switching** functionality
