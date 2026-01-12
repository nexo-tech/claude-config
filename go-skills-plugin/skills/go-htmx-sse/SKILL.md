---
name: go-htmx-sse
description: Server-Sent Events for real-time updates with Go and HTMX. Streaming responses, live notifications, and clawde integration.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Go + HTMX Server-Sent Events

Build real-time features using Server-Sent Events. Stream updates from Go to browser without WebSocket complexity.

## When to Use

- Real-time notifications and alerts
- Live log streaming
- Progress indicators for long operations
- Agent/AI response streaming (clawde)
- Live dashboards with auto-updating data
- Chat message delivery

---

## SSE vs WebSocket vs Polling

| Feature | SSE | WebSocket | Polling |
|---------|-----|-----------|---------|
| Direction | Server → Client | Bidirectional | Client → Server |
| Complexity | Simple | Complex | Simple |
| Auto-reconnect | Built-in | Manual | N/A |
| Browser support | All modern | All modern | All |
| HTTP/2 multiplexing | Yes | No | Yes |
| Best for | Updates, streams | Chat, games | Legacy |

**Choose SSE when**: You need server-to-client updates (most cases).

---

## Basic SSE Handler

### Go Handler with http.Flusher

```go
func handleSSE(w http.ResponseWriter, r *http.Request) {
    // Set SSE headers
    w.Header().Set("Content-Type", "text/event-stream")
    w.Header().Set("Cache-Control", "no-cache")
    w.Header().Set("Connection", "keep-alive")

    // Get flusher for streaming
    flusher, ok := w.(http.Flusher)
    if !ok {
        http.Error(w, "SSE not supported", http.StatusInternalServerError)
        return
    }

    // Stream events until client disconnects
    ctx := r.Context()
    ticker := time.NewTicker(time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return  // Client disconnected
        case t := <-ticker.C:
            fmt.Fprintf(w, "data: %s\n\n", t.Format(time.RFC3339))
            flusher.Flush()
        }
    }
}
```

### Register Route

```go
mux.HandleFunc("GET /events", handleSSE)
```

---

## SSE Event Format

### Basic Event

```
data: Hello World\n\n
```

### Event with Type

```
event: notification
data: {"message": "New item created"}

```

### Multi-line Data

```
data: Line 1
data: Line 2
data: Line 3

```

### Event with ID (for reconnection)

```
id: 123
event: update
data: {"count": 42}

```

### Retry Interval (milliseconds)

```
retry: 5000
data: reconnect in 5s if disconnected

```

---

## Go Event Helpers

### Event Writer

```go
type SSEWriter struct {
    w       http.ResponseWriter
    flusher http.Flusher
}

func NewSSEWriter(w http.ResponseWriter) (*SSEWriter, error) {
    flusher, ok := w.(http.Flusher)
    if !ok {
        return nil, fmt.Errorf("streaming not supported")
    }

    w.Header().Set("Content-Type", "text/event-stream")
    w.Header().Set("Cache-Control", "no-cache")
    w.Header().Set("Connection", "keep-alive")

    return &SSEWriter{w: w, flusher: flusher}, nil
}

func (s *SSEWriter) SendEvent(event, data string) {
    if event != "" {
        fmt.Fprintf(s.w, "event: %s\n", event)
    }
    fmt.Fprintf(s.w, "data: %s\n\n", data)
    s.flusher.Flush()
}

func (s *SSEWriter) SendData(data string) {
    fmt.Fprintf(s.w, "data: %s\n\n", data)
    s.flusher.Flush()
}

func (s *SSEWriter) SendHTML(event string, html string) {
    // Escape newlines in HTML for SSE
    escaped := strings.ReplaceAll(html, "\n", "")
    s.SendEvent(event, escaped)
}
```

### Usage

```go
func handleStream(w http.ResponseWriter, r *http.Request) {
    sse, err := NewSSEWriter(w)
    if err != nil {
        http.Error(w, err.Error(), 500)
        return
    }

    for msg := range messages {
        sse.SendEvent("message", msg)
    }
}
```

---

## HTMX SSE Extension

### Load Extension

```html
<script src="/static/js/htmx.min.js"></script>
<script src="/static/js/sse.js"></script>
```

Or from CDN:
```html
<script src="https://unpkg.com/htmx-ext-sse@2.2.2/sse.js"></script>
```

### Connect to SSE Endpoint

```html
<div hx-ext="sse" sse-connect="/events">
    <!-- Content updated by SSE -->
</div>
```

### Swap on Specific Event

```html
<div hx-ext="sse" sse-connect="/events" sse-swap="message">
    <!-- Swapped when 'message' event received -->
</div>
```

### Multiple Event Handlers

```html
<div hx-ext="sse" sse-connect="/events">
    <div sse-swap="notification" hx-swap="beforeend">
        <!-- Notifications append here -->
    </div>
    <div sse-swap="status" hx-swap="innerHTML">
        <!-- Status updates replace content -->
    </div>
</div>
```

---

## Templ Components for SSE

### Live Container

```templ
templ LiveNotifications() {
    <div
        hx-ext="sse"
        sse-connect="/notifications/stream"
        sse-swap="notification"
        hx-swap="beforeend"
        class="space-y-2"
    >
        <!-- Notifications appear here -->
    </div>
}
```

### Notification Fragment

```templ
templ NotificationItem(msg Notification) {
    <div class="p-4 bg-blue-50 rounded-lg border border-blue-200 animate-fade-in">
        <p class="font-medium">{ msg.Title }</p>
        <p class="text-sm text-gray-600">{ msg.Body }</p>
    </div>
}
```

### Handler Sending HTML Fragment

```go
func handleNotificationStream(w http.ResponseWriter, r *http.Request) {
    sse, _ := NewSSEWriter(w)
    ctx := r.Context()

    for {
        select {
        case <-ctx.Done():
            return
        case notification := <-notificationChan:
            var buf bytes.Buffer
            NotificationItem(notification).Render(ctx, &buf)
            sse.SendHTML("notification", buf.String())
        }
    }
}
```

---

## Clawde Integration

### Streaming Agent Responses

```go
func handleAgentStream(w http.ResponseWriter, r *http.Request) {
    sse, err := NewSSEWriter(w)
    if err != nil {
        http.Error(w, err.Error(), 500)
        return
    }

    client := clawde.NewClient(
        clawde.WithModel("claude-sonnet-4-20250514"),
        clawde.WithSystemPrompt("You are a helpful assistant."),
    )

    prompt := r.URL.Query().Get("prompt")
    ctx := r.Context()

    stream, err := client.Query(ctx, prompt)
    if err != nil {
        sse.SendEvent("error", err.Error())
        return
    }

    for stream.Next() {
        msg := stream.Current()

        switch m := msg.(type) {
        case *clawde.AssistantMessage:
            // Send text chunks
            for _, block := range m.Content {
                if text, ok := block.(*clawde.TextBlock); ok {
                    var buf bytes.Buffer
                    MessageChunk(text.Text).Render(ctx, &buf)
                    sse.SendHTML("chunk", buf.String())
                }
            }

        case *clawde.ToolUseMessage:
            // Send tool use notification
            var buf bytes.Buffer
            ToolUseCard(m.Name, m.Input).Render(ctx, &buf)
            sse.SendHTML("tool", buf.String())

        case *clawde.ResultMessage:
            // Send completion
            sse.SendEvent("done", `{"status": "complete"}`)
        }
    }

    if err := stream.Err(); err != nil {
        sse.SendEvent("error", err.Error())
    }
}
```

### Message Components

```templ
templ MessageChunk(text string) {
    <span>{ text }</span>
}

templ ToolUseCard(name string, input string) {
    <div class="bg-gray-100 rounded p-2 my-2 text-sm">
        <span class="font-mono text-blue-600">{ name }</span>
    </div>
}

templ AgentStreamContainer() {
    <div
        hx-ext="sse"
        sse-connect="/agent/stream?prompt=Hello"
        class="space-y-2"
    >
        <div sse-swap="chunk" hx-swap="beforeend" id="output">
            <!-- Streaming text appears here -->
        </div>
        <div sse-swap="tool" hx-swap="beforeend">
            <!-- Tool use cards appear here -->
        </div>
        <div sse-swap="done" hx-swap="innerHTML" id="status">
            <!-- Completion status -->
        </div>
    </div>
}
```

---

## Fan-Out Hub Pattern

For broadcasting to multiple clients.

### Hub Implementation

```go
type Hub struct {
    clients    map[chan string]bool
    broadcast  chan string
    register   chan chan string
    unregister chan chan string
    mu         sync.RWMutex
}

func NewHub() *Hub {
    h := &Hub{
        clients:    make(map[chan string]bool),
        broadcast:  make(chan string, 256),
        register:   make(chan chan string),
        unregister: make(chan chan string),
    }
    go h.run()
    return h
}

func (h *Hub) run() {
    for {
        select {
        case client := <-h.register:
            h.mu.Lock()
            h.clients[client] = true
            h.mu.Unlock()

        case client := <-h.unregister:
            h.mu.Lock()
            if _, ok := h.clients[client]; ok {
                delete(h.clients, client)
                close(client)
            }
            h.mu.Unlock()

        case msg := <-h.broadcast:
            h.mu.RLock()
            for client := range h.clients {
                select {
                case client <- msg:
                default:
                    // Client buffer full, skip
                }
            }
            h.mu.RUnlock()
        }
    }
}

func (h *Hub) Subscribe() chan string {
    ch := make(chan string, 16)
    h.register <- ch
    return ch
}

func (h *Hub) Unsubscribe(ch chan string) {
    h.unregister <- ch
}

func (h *Hub) Broadcast(msg string) {
    h.broadcast <- msg
}
```

### Usage

```go
var hub = NewHub()

func handleBroadcastSSE(w http.ResponseWriter, r *http.Request) {
    sse, _ := NewSSEWriter(w)
    ctx := r.Context()

    ch := hub.Subscribe()
    defer hub.Unsubscribe(ch)

    for {
        select {
        case <-ctx.Done():
            return
        case msg := <-ch:
            sse.SendData(msg)
        }
    }
}

func handlePostMessage(w http.ResponseWriter, r *http.Request) {
    msg := r.FormValue("message")
    hub.Broadcast(msg)
    w.WriteHeader(http.StatusOK)
}
```

---

## Progress Streaming

### Long Operation with Progress

```go
func handleUploadProcess(w http.ResponseWriter, r *http.Request) {
    sse, _ := NewSSEWriter(w)
    ctx := r.Context()

    // Simulate processing stages
    stages := []string{"Uploading", "Processing", "Analyzing", "Complete"}

    for i, stage := range stages {
        select {
        case <-ctx.Done():
            return
        default:
            progress := (i + 1) * 100 / len(stages)
            var buf bytes.Buffer
            ProgressBar(stage, progress).Render(ctx, &buf)
            sse.SendHTML("progress", buf.String())
            time.Sleep(time.Second)
        }
    }

    sse.SendEvent("done", "true")
}
```

### Progress Component

```templ
templ ProgressBar(stage string, percent int) {
    <div class="space-y-2">
        <div class="flex justify-between text-sm">
            <span>{ stage }</span>
            <span>{ fmt.Sprintf("%d%%", percent) }</span>
        </div>
        <div class="w-full bg-gray-200 rounded-full h-2">
            <div
                class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                style={ fmt.Sprintf("width: %d%%", percent) }
            ></div>
        </div>
    </div>
}

templ ProgressContainer() {
    <div
        hx-ext="sse"
        sse-connect="/upload/process"
        sse-swap="progress"
    >
        @ProgressBar("Starting...", 0)
    </div>
}
```

---

## Auto-Scroll on New Messages

### JavaScript Helper

```templ
templ ChatContainer() {
    <div
        id="chat"
        hx-ext="sse"
        sse-connect="/chat/stream"
        sse-swap="message"
        hx-swap="beforeend scroll:bottom"
        class="h-96 overflow-y-auto"
    >
        <!-- Messages appear here -->
    </div>
}
```

With custom scroll behavior:
```html
<div
    hx-ext="sse"
    sse-connect="/chat"
    sse-swap="message"
    hx-swap="beforeend"
    hx-on::sse-message="this.scrollTop = this.scrollHeight"
>
```

---

## Error Handling

### Retry Configuration

```go
func handleSSE(w http.ResponseWriter, r *http.Request) {
    sse, _ := NewSSEWriter(w)

    // Tell client to retry in 3 seconds if disconnected
    fmt.Fprintf(sse.w, "retry: 3000\n\n")
    sse.flusher.Flush()

    // ... stream events
}
```

### Error Event

```go
func handleSSE(w http.ResponseWriter, r *http.Request) {
    sse, _ := NewSSEWriter(w)

    err := doSomething()
    if err != nil {
        sse.SendEvent("error", fmt.Sprintf(`{"message": "%s"}`, err.Error()))
        return
    }
}
```

### Client Error Handling

```html
<div
    hx-ext="sse"
    sse-connect="/events"
    sse-swap="update"
    hx-on::sse-error="handleSSEError(event)"
>
```

```javascript
function handleSSEError(event) {
    console.error('SSE error:', event.detail);
    // Show user-friendly error message
}
```

---

## Graceful Shutdown

### Context Cancellation

```go
func handleSSE(w http.ResponseWriter, r *http.Request) {
    sse, _ := NewSSEWriter(w)
    ctx := r.Context()

    // Create cancellable context
    ctx, cancel := context.WithCancel(ctx)
    defer cancel()

    // Listen for server shutdown
    go func() {
        <-serverShutdown
        cancel()
    }()

    for {
        select {
        case <-ctx.Done():
            // Send close event before returning
            sse.SendEvent("close", "server shutting down")
            return
        case data := <-dataChan:
            sse.SendData(data)
        }
    }
}
```

---

## Best Practices

### 1. Use Named Events

```go
// Good - client can filter
sse.SendEvent("user-joined", userData)
sse.SendEvent("user-left", userData)
sse.SendEvent("message", messageData)

// Bad - client processes everything
sse.SendData(genericData)
```

### 2. Keep Events Small

```go
// Good - send only what changed
sse.SendEvent("count", fmt.Sprintf("%d", count))

// Bad - send entire state
sse.SendEvent("state", entireAppState)
```

### 3. Use Event IDs for Reconnection

```go
func (s *SSEWriter) SendEventWithID(id, event, data string) {
    fmt.Fprintf(s.w, "id: %s\n", id)
    fmt.Fprintf(s.w, "event: %s\n", event)
    fmt.Fprintf(s.w, "data: %s\n\n", data)
    s.flusher.Flush()
}
```

### 4. Heartbeat to Detect Disconnects

```go
func handleSSE(w http.ResponseWriter, r *http.Request) {
    sse, _ := NewSSEWriter(w)
    ctx := r.Context()

    heartbeat := time.NewTicker(30 * time.Second)
    defer heartbeat.Stop()

    for {
        select {
        case <-ctx.Done():
            return
        case <-heartbeat.C:
            sse.SendEvent("heartbeat", "ping")
        case data := <-dataChan:
            sse.SendData(data)
        }
    }
}
```

---

## Integration

This skill works with:
- **go-project-bootstrap**: Initial project setup
- **go-htmx-core**: Handler patterns and routing
- **go-templ-components**: HTML fragment rendering
- **go-htmx-dashboard**: Real-time dashboard updates
- **go-pico-embed**: Asset embedding and deployment

Reference this skill when implementing real-time features.
