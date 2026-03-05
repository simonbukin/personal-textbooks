# Agent Backends

## Why This Matters

So far, LLMs have answered questions. Agents take actions.

An agent is an LLM that can use tools — search databases, call APIs, send emails, modify data. Instead of just generating text, it decides what to do and does it.

This is powerful but risky. An agent with database access can delete records. An agent with email access can spam users. Building agents requires careful design around what they can and cannot do.

## How Agents Work

```
User: "Create a task to review the Q3 report and assign it to Sarah"
          │
          ▼
    ┌─────────────┐
    │     LLM     │  Decides to use createTask tool
    │             │
    └──────┬──────┘
           │ Tool call: createTask({title: "Review Q3 report", assignee: "sarah@..."})
           ▼
    ┌─────────────┐
    │   Backend   │  Executes the tool
    │  Executor   │
    └──────┬──────┘
           │ Result: {id: "task_123", created: true}
           ▼
    ┌─────────────┐
    │     LLM     │  Generates response using result
    │             │
    └──────┬──────┘
           │
           ▼
    Response: "I've created the task and assigned it to Sarah."
```

## Tool Definition

Tools are functions the LLM can call. Define them with clear schemas:

```typescript
// src/agents/tools.ts
import { z } from 'zod'

export interface Tool {
  name: string
  description: string
  parameters: z.ZodSchema
  execute: (params: unknown, context: AgentContext) => Promise<unknown>
}

export const searchTasksTool: Tool = {
  name: 'searchTasks',
  description: 'Search for tasks by keyword, status, or assignee',
  parameters: z.object({
    query: z.string().optional().describe('Search keywords'),
    status: z.enum(['pending', 'in_progress', 'completed']).optional(),
    assigneeEmail: z.string().email().optional(),
    limit: z.number().min(1).max(20).default(10),
  }),
  execute: async (params, context) => {
    const validated = searchTasksTool.parameters.parse(params)

    const tasks = await context.db.query.tasks.findMany({
      where: and(
        validated.query ? ilike(tasks.title, `%${validated.query}%`) : undefined,
        validated.status ? eq(tasks.status, validated.status) : undefined,
        validated.assigneeEmail ? eq(tasks.assigneeEmail, validated.assigneeEmail) : undefined,
        // Always scope to user's workspace
        eq(tasks.workspaceId, context.workspaceId),
      ),
      limit: validated.limit,
    })

    return tasks.map(t => ({
      id: t.id,
      title: t.title,
      status: t.status,
      assignee: t.assigneeEmail,
      dueDate: t.dueDate,
    }))
  },
}

export const createTaskTool: Tool = {
  name: 'createTask',
  description: 'Create a new task in the current workspace',
  parameters: z.object({
    title: z.string().min(1).max(200),
    description: z.string().optional(),
    dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    assigneeEmail: z.string().email().optional(),
    priority: z.enum(['low', 'medium', 'high']).default('medium'),
  }),
  execute: async (params, context) => {
    const validated = createTaskTool.parameters.parse(params)

    const task = await context.db.insert(tasks).values({
      ...validated,
      workspaceId: context.workspaceId,
      createdBy: context.userId,
    }).returning()

    return {
      success: true,
      taskId: task[0].id,
      title: task[0].title,
    }
  },
}
```

## Agent Execution Loop

The core agent loop: send message with tools, execute tool calls, continue until done:

```typescript
// src/agents/executor.ts
import Anthropic from '@anthropic-ai/sdk'

interface AgentContext {
  db: Database
  userId: string
  workspaceId: string
}

export async function runAgent(
  userMessage: string,
  tools: Tool[],
  context: AgentContext
): Promise<string> {
  const anthropic = new Anthropic()

  // Convert tools to Anthropic format
  const toolDefs = tools.map(t => ({
    name: t.name,
    description: t.description,
    input_schema: zodToJsonSchema(t.parameters),
  }))

  const messages: Anthropic.Message[] = []
  let currentMessages: Anthropic.MessageParam[] = [
    { role: 'user', content: userMessage }
  ]

  const MAX_ITERATIONS = 10

  for (let i = 0; i < MAX_ITERATIONS; i++) {
    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      system: `You are a helpful assistant that can manage tasks.
Use the available tools to help the user.
Always confirm what you did after taking an action.`,
      tools: toolDefs,
      messages: currentMessages,
    })

    // Check if we're done (no tool use)
    if (response.stop_reason === 'end_turn') {
      const textContent = response.content.find(c => c.type === 'text')
      return textContent?.text ?? ''
    }

    // Process tool calls
    const toolUseBlocks = response.content.filter(c => c.type === 'tool_use')

    if (toolUseBlocks.length === 0) {
      const textContent = response.content.find(c => c.type === 'text')
      return textContent?.text ?? ''
    }

    // Execute each tool
    const toolResults: Anthropic.ToolResultBlockParam[] = []

    for (const toolUse of toolUseBlocks) {
      if (toolUse.type !== 'tool_use') continue

      const tool = tools.find(t => t.name === toolUse.name)
      if (!tool) {
        toolResults.push({
          type: 'tool_result',
          tool_use_id: toolUse.id,
          content: `Error: Unknown tool ${toolUse.name}`,
          is_error: true,
        })
        continue
      }

      try {
        const result = await tool.execute(toolUse.input, context)
        toolResults.push({
          type: 'tool_result',
          tool_use_id: toolUse.id,
          content: JSON.stringify(result),
        })
      } catch (error) {
        toolResults.push({
          type: 'tool_result',
          tool_use_id: toolUse.id,
          content: `Error: ${error.message}`,
          is_error: true,
        })
      }
    }

    // Add assistant response and tool results to messages
    currentMessages = [
      ...currentMessages,
      { role: 'assistant', content: response.content },
      { role: 'user', content: toolResults },
    ]
  }

  throw new Error('Agent exceeded maximum iterations')
}
```

## Safety Controls

Agents can do damage. Build in guardrails.

### Action Confirmation

For destructive actions, require confirmation:

```typescript
export const deleteTaskTool: Tool = {
  name: 'deleteTask',
  description: 'Delete a task. This action is irreversible.',
  parameters: z.object({
    taskId: z.string().uuid(),
    confirm: z.literal(true).describe('Must be true to confirm deletion'),
  }),
  execute: async (params, context) => {
    const validated = deleteTaskTool.parameters.parse(params)

    // Verify task belongs to workspace
    const task = await context.db.query.tasks.findFirst({
      where: and(
        eq(tasks.id, validated.taskId),
        eq(tasks.workspaceId, context.workspaceId),
      ),
    })

    if (!task) {
      throw new Error('Task not found or access denied')
    }

    await context.db.delete(tasks).where(eq(tasks.id, validated.taskId))

    return { success: true, deleted: validated.taskId }
  },
}
```

### Rate Limiting Actions

Prevent agents from taking too many actions:

```typescript
interface RateLimits {
  maxActionsPerMinute: number
  maxActionsPerSession: number
}

const DEFAULT_LIMITS: RateLimits = {
  maxActionsPerMinute: 10,
  maxActionsPerSession: 50,
}

class ActionRateLimiter {
  private actionCounts = new Map<string, { minute: number; session: number; lastMinute: number }>()

  checkAndIncrement(sessionId: string, limits = DEFAULT_LIMITS): boolean {
    const now = Math.floor(Date.now() / 60000)  // Current minute
    const entry = this.actionCounts.get(sessionId) ?? { minute: 0, session: 0, lastMinute: now }

    // Reset minute counter if new minute
    if (entry.lastMinute !== now) {
      entry.minute = 0
      entry.lastMinute = now
    }

    // Check limits
    if (entry.minute >= limits.maxActionsPerMinute) {
      throw new Error('Rate limit exceeded: too many actions per minute')
    }
    if (entry.session >= limits.maxActionsPerSession) {
      throw new Error('Rate limit exceeded: too many actions in session')
    }

    // Increment counters
    entry.minute++
    entry.session++
    this.actionCounts.set(sessionId, entry)

    return true
  }
}
```

### Scoped Permissions

Limit what tools are available based on context:

```typescript
function getToolsForUser(user: User): Tool[] {
  const baseTools = [searchTasksTool, createTaskTool]

  if (user.role === 'admin') {
    return [...baseTools, deleteTaskTool, bulkUpdateTool]
  }

  return baseTools
}

// In agent execution
const tools = getToolsForUser(context.user)
const response = await runAgent(message, tools, context)
```

### Audit Logging

Log all agent actions:

```typescript
async function executeToolWithAudit(
  tool: Tool,
  params: unknown,
  context: AgentContext
): Promise<unknown> {
  const startTime = Date.now()

  try {
    const result = await tool.execute(params, context)

    await context.db.insert(agentAuditLog).values({
      userId: context.userId,
      toolName: tool.name,
      input: JSON.stringify(params),
      output: JSON.stringify(result),
      success: true,
      durationMs: Date.now() - startTime,
    })

    return result
  } catch (error) {
    await context.db.insert(agentAuditLog).values({
      userId: context.userId,
      toolName: tool.name,
      input: JSON.stringify(params),
      error: error.message,
      success: false,
      durationMs: Date.now() - startTime,
    })

    throw error
  }
}
```

## Multi-Step Workflows

Agents can chain multiple actions to complete complex tasks:

```typescript
// User: "Move all tasks assigned to John that are overdue to the backlog"

// Agent reasoning:
// 1. Search for tasks assigned to John that are overdue
// 2. For each task, update status to "backlog"
// 3. Report what was done

export const updateTaskTool: Tool = {
  name: 'updateTask',
  description: 'Update an existing task',
  parameters: z.object({
    taskId: z.string().uuid(),
    updates: z.object({
      title: z.string().optional(),
      status: z.enum(['pending', 'in_progress', 'completed', 'backlog']).optional(),
      dueDate: z.string().nullable().optional(),
      assigneeEmail: z.string().email().nullable().optional(),
    }),
  }),
  execute: async (params, context) => {
    const validated = updateTaskTool.parameters.parse(params)

    // Verify access
    const task = await context.db.query.tasks.findFirst({
      where: and(
        eq(tasks.id, validated.taskId),
        eq(tasks.workspaceId, context.workspaceId),
      ),
    })

    if (!task) {
      throw new Error('Task not found or access denied')
    }

    const updated = await context.db.update(tasks)
      .set(validated.updates)
      .where(eq(tasks.id, validated.taskId))
      .returning()

    return { success: true, task: updated[0] }
  },
}
```

## Streaming Agent Responses

For better UX, stream both text and tool use:

```typescript
app.post('/api/agent', async (c) => {
  const { message } = await c.req.json()
  const context = buildAgentContext(c)

  return c.stream(async (stream) => {
    const tools = getToolsForUser(context.user)

    await streamAgent(message, tools, context, {
      onText: async (text) => {
        await stream.write(`data: ${JSON.stringify({ type: 'text', content: text })}\n\n`)
      },
      onToolStart: async (tool, params) => {
        await stream.write(`data: ${JSON.stringify({
          type: 'tool_start',
          tool: tool.name,
          params,
        })}\n\n`)
      },
      onToolEnd: async (tool, result) => {
        await stream.write(`data: ${JSON.stringify({
          type: 'tool_end',
          tool: tool.name,
          result,
        })}\n\n`)
      },
    })

    await stream.write('data: [DONE]\n\n')
  })
})
```

## Handling Failures

Agents will encounter errors. Handle them gracefully:

```typescript
async function executeToolSafely(
  tool: Tool,
  params: unknown,
  context: AgentContext
): Promise<{ success: boolean; result?: unknown; error?: string }> {
  try {
    const result = await tool.execute(params, context)
    return { success: true, result }
  } catch (error) {
    // Log for debugging
    console.error(`Tool ${tool.name} failed:`, error)

    // Return user-friendly error
    if (error instanceof z.ZodError) {
      return {
        success: false,
        error: `Invalid parameters: ${error.errors.map(e => e.message).join(', ')}`,
      }
    }

    return {
      success: false,
      error: error.message || 'An unexpected error occurred',
    }
  }
}
```

The LLM should handle errors and potentially retry with different parameters:

```typescript
// System prompt addition
const systemPrompt = `...
If a tool returns an error, explain the issue to the user and ask for clarification if needed.
Do not retry the same tool with the same parameters more than once.
`
```

## The Taste Test

**Scenario 1:** An agent has a `deleteDatabase` tool available "just in case."

*Never.* Tools define the agent's capabilities. Only provide tools appropriate for the use case. No production agent needs database deletion.

**Scenario 2:** An agent creates 100 tasks in a loop because the user said "create a task for each item in this list."

*Add limits.* Bulk operations should be explicit tools with batch limits, not loops of single-item tools.

**Scenario 3:** An agent can search all workspaces, not just the user's.

*Security hole.* Every tool must scope to the user's permissions. Never trust the LLM to respect boundaries — enforce them in code.

**Scenario 4:** Agent actions aren't logged, making it impossible to debug issues or audit behavior.

*Must log.* Agents are unpredictable. Comprehensive logging is essential for debugging, security, and understanding behavior.

## Practical Exercise

Build an agent for TaskFlow that can:

**Tools to implement:**
1. `searchTasks` — Find tasks by various criteria
2. `createTask` — Create a new task
3. `updateTask` — Modify an existing task
4. `getTaskDetails` — Get full details of a specific task
5. `listProjects` — List available projects

**Requirements:**
- All tools scoped to user's workspace
- Action logging for audit
- Rate limiting (10 actions/minute)
- Streaming responses

**Test scenarios:**
- "Show me all my overdue tasks"
- "Create a task to review the Q3 report, due next Friday"
- "Mark task-123 as completed"
- "What tasks are assigned to sarah@company.com?"

**Acceptance criteria:**
- Agent completes multi-step workflows
- Actions are logged with inputs/outputs
- Rate limits prevent runaway execution
- Errors are handled gracefully

## Checkpoint

After completing this chapter, you should be able to confidently say:

- [ ] I can define tools with schemas for LLM agents
- [ ] I understand the agent execution loop
- [ ] I know how to implement safety controls (scoping, limits, logging)
- [ ] I can build multi-step agent workflows
- [ ] I understand the risks of agent systems and how to mitigate them

Agents are powerful but require careful design. They're not just LLMs — they're LLMs with the ability to affect the world. Treat that capability with appropriate caution.
