# Capstone: AI-Powered Feature

## The Challenge

You've learned LLM integration, RAG, and agents. Now build a complete AI-powered feature that demonstrates all three.

This capstone is about shipping something real — not a toy demo, but a feature that could go into a production application.

## The Task

Build a **Smart Task Assistant** for your TaskFlow application.

The assistant should:
- Understand natural language queries about tasks
- Retrieve relevant context from task history and documentation
- Take actions (create, update, search tasks)
- Maintain conversation context across messages

## Feature Specification

### Natural Language Queries

Users can ask questions in natural language:

- "What tasks are due this week?"
- "Show me everything assigned to Sarah"
- "What did I work on last month?"

The assistant searches and returns relevant results.

### Task Actions

Users can request actions:

- "Create a task to review the Q3 report, due Friday"
- "Mark the deployment task as complete"
- "Assign all design tasks to Maria"

The assistant executes the action and confirms.

### Context-Aware Responses

The assistant knows about:
- User's tasks and projects
- Task history and activity
- Workspace members
- Any documentation you've indexed

For example: "What's the status of the website redesign?" should pull relevant tasks AND any design documents that mention it.

## Technical Requirements

### 1. Conversation API

```typescript
POST /api/assistant/chat
{
  "message": "What tasks are due this week?",
  "conversationId": "conv_123"  // Optional, for context
}

Response (streaming SSE):
data: {"type": "thinking", "content": "Searching for tasks..."}
data: {"type": "tool_call", "tool": "searchTasks", "params": {...}}
data: {"type": "text", "content": "You have 5 tasks due this week..."}
data: [DONE]
```

### 2. Tool Suite

Implement at least these tools:
- `searchTasks` — Query tasks by various criteria
- `createTask` — Create new tasks
- `updateTask` — Modify existing tasks
- `searchDocuments` — RAG search over indexed content
- `getCurrentDate` — For relative date calculations

### 3. RAG Integration

Index and search:
- Task descriptions and comments
- Project documentation
- Any knowledge base content

Use this for queries like "What was the decision on the authentication approach?"

### 4. Safety and Limits

- All actions scoped to user's workspace
- Rate limiting on actions
- Audit logging
- Confirmation for destructive operations

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Frontend/Client                    │
│  - Chat interface                                   │
│  - Streaming response display                       │
│  - Tool execution visualization                     │
└────────────────────────┬────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│                  Assistant API                       │
│  POST /api/assistant/chat                           │
│  - Conversation management                          │
│  - Context retrieval                                │
│  - Agent orchestration                              │
└────────────────────────┬────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    ┌─────────┐    ┌──────────┐    ┌──────────┐
    │   LLM   │    │  Vector  │    │  Task    │
    │  (API)  │    │   Store  │    │   DB     │
    └─────────┘    └──────────┘    └──────────┘
```

## Deliverables

### 1. Working Assistant API

- Streaming conversation endpoint
- Conversation history management
- At least 5 functional tools

### 2. RAG Pipeline

- Document ingestion for task content
- Semantic search integration
- Hybrid retrieval (if applicable)

### 3. Agent Implementation

- Tool definition with schemas
- Execution loop with error handling
- Safety controls (scoping, limits, logging)

### 4. Demo Script

A document showing 5-10 example conversations demonstrating:
- Natural language understanding
- Multi-step workflows
- RAG-grounded responses
- Error handling

## Evaluation Criteria

### Functionality

- [ ] Natural language queries return relevant results
- [ ] Actions execute correctly and safely
- [ ] Conversation context is maintained
- [ ] RAG search improves response quality

### Engineering Quality

- [ ] Code is well-structured and maintainable
- [ ] Errors are handled gracefully
- [ ] Streaming works correctly
- [ ] Actions are logged and auditable

### Safety

- [ ] All actions scoped to user's permissions
- [ ] Rate limits prevent abuse
- [ ] Destructive actions require confirmation
- [ ] No data leaks across workspaces

## Example Conversations

**Simple Query:**
```
User: "What tasks do I have due this week?"
Assistant: [calls searchTasks with due date filter]
"You have 3 tasks due this week:
1. Review PR for authentication feature (due Tuesday)
2. Update onboarding documentation (due Thursday)
3. Team standup preparation (due Friday)"
```

**Task Creation:**
```
User: "Create a task to prepare the Q4 planning presentation, due next Monday, high priority"
Assistant: [calls createTask]
"Created: 'Prepare Q4 planning presentation'
- Due: Monday, January 20
- Priority: High
- Status: Pending

Would you like me to assign this to anyone?"
```

**Context-Aware Query:**
```
User: "What did we decide about the payment integration?"
Assistant: [calls searchDocuments]
"Based on the technical design doc from November:

You decided to use Stripe for payment processing. Key decisions:
- Webhook-based confirmation (not polling)
- Idempotency keys for all payment operations
- Separate payment service from main API

The related tasks are:
1. Set up Stripe account (completed)
2. Implement webhook handlers (in progress)
3. Add payment UI components (pending)"
```

**Multi-Step Workflow:**
```
User: "Move all of John's tasks to Sarah since John is on leave"
Assistant: [calls searchTasks]
"I found 4 tasks currently assigned to John:
1. API documentation update
2. Performance testing
3. Code review backlog
4. Sprint planning

[calls updateTask for each]
I've reassigned all 4 tasks to Sarah. Would you like me to notify her?"
```

## Hints and Guidance

### Start Simple

Build the conversation loop first with one tool. Get streaming working. Then add more tools and RAG.

### Use Existing Code

You've built RAG and agents in previous chapters. Reuse that code. This capstone is integration, not rewriting.

### Test Conversation Flow

The hardest part is multi-turn conversation. Test cases where the user refers to previous context:
- "What about the first one?" (referring to a list)
- "Mark that as done" (referring to a mentioned task)
- "Can you also add a description?" (continuing previous action)

### Watch Token Usage

Long conversations consume tokens. Consider:
- Summarizing old context
- Limiting retrieved documents
- Truncating very long tool results

## Timeline

**Week 1:**
- Days 1-2: Set up conversation API with streaming
- Days 3-4: Implement core tools (search, create, update)
- Day 5: Integrate RAG search

**Week 2:**
- Days 1-2: Build multi-turn conversation handling
- Days 3-4: Add safety controls and logging
- Day 5: Testing and demo preparation

## What You're Proving

This capstone demonstrates:
- **Integration skills:** Combining LLMs, RAG, and tools into a cohesive feature
- **Production thinking:** Safety, logging, error handling
- **UX awareness:** Streaming, clear responses, confirmation flows
- **Technical depth:** Understanding how these AI components work together

Building AI features isn't about calling APIs — it's about orchestrating multiple systems to create useful experiences. That's what this project proves you can do.
