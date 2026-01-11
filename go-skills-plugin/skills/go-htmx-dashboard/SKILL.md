---
name: go-htmx-dashboard
description: Dashboard and admin UI patterns with Go + HTMX + clawde. Kanban boards, data tables, real-time agent control, and status indicators.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Go + HTMX Dashboard Patterns

Build admin dashboards and control panels with Go, HTMX, and clawde. Real-time updates, data visualization, and agent streaming.

## When to Use

- Building admin panels and dashboards
- Agent/AI control interfaces
- Real-time monitoring systems
- Data management UIs

---

## Dashboard Layout

### Base Layout

```templ
templ DashboardLayout(title string, activeNav string) {
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>{ title } | Dashboard</title>
        <link rel="stylesheet" href="/static/css/tailwind.css"/>
        <script src="/static/js/htmx.min.js"></script>
        <script src="/static/js/sse.js"></script>
    </head>
    <body class="bg-gray-50">
        <div class="flex h-screen">
            @Sidebar(activeNav)
            <main class="flex-1 overflow-auto">
                @TopBar(title)
                <div class="p-6">
                    { children... }
                </div>
            </main>
        </div>
    </body>
    </html>
}
```

### Sidebar Navigation

```templ
type NavItem struct {
    Name   string
    Href   string
    Icon   string
}

var navItems = []NavItem{
    {Name: "Dashboard", Href: "/", Icon: "home"},
    {Name: "Pipeline", Href: "/pipeline", Icon: "kanban"},
    {Name: "Control", Href: "/control", Icon: "terminal"},
    {Name: "Runs", Href: "/runs", Icon: "history"},
    {Name: "Settings", Href: "/settings", Icon: "settings"},
}

templ Sidebar(activeNav string) {
    <aside class="w-64 bg-gray-900 text-white">
        <div class="p-4">
            <h1 class="text-xl font-bold">Agent Dashboard</h1>
        </div>
        <nav class="mt-4">
            for _, item := range navItems {
                <a
                    href={ templ.SafeURL(item.Href) }
                    hx-boost="true"
                    class={
                        "flex items-center px-4 py-3 text-sm",
                        templ.KV("bg-gray-800 text-white", activeNav == item.Name),
                        templ.KV("text-gray-400 hover:bg-gray-800", activeNav != item.Name),
                    }
                >
                    @Icon(item.Icon, "w-5 h-5 mr-3")
                    { item.Name }
                </a>
            }
        </nav>
    </aside>
}
```

---

## Kanban Board

### Board Container

```templ
type Stage struct {
    ID    string
    Name  string
    Items []Item
}

templ KanbanBoard(stages []Stage) {
    <div class="flex gap-4 overflow-x-auto pb-4">
        for _, stage := range stages {
            @StageColumn(stage)
        }
    </div>
}

templ StageColumn(stage Stage) {
    <div class="w-80 flex-shrink-0 bg-gray-100 rounded-lg">
        <div class="p-3 font-medium text-gray-700 border-b border-gray-200 flex justify-between">
            <span>{ stage.Name }</span>
            <span class="bg-gray-200 px-2 py-0.5 rounded-full text-sm">
                { fmt.Sprint(len(stage.Items)) }
            </span>
        </div>
        <div
            id={ "stage-" + stage.ID }
            class="p-2 space-y-2 min-h-[200px]"
            hx-get={ "/api/stage/" + stage.ID }
            hx-trigger="every 30s"
            hx-swap="innerHTML"
        >
            for _, item := range stage.Items {
                @KanbanCard(item)
            }
            if len(stage.Items) == 0 {
                <div class="text-center py-8 text-gray-400 text-sm">
                    No items
                </div>
            }
        </div>
    </div>
}
```

### Kanban Card

```templ
type Item struct {
    ID          string
    Title       string
    Description string
    Status      string
    Priority    string
    CreatedAt   time.Time
}

templ KanbanCard(item Item) {
    <div
        id={ "item-" + item.ID }
        class="bg-white rounded-lg shadow-sm p-3 cursor-pointer hover:shadow-md transition-shadow"
        hx-get={ "/items/" + item.ID }
        hx-target="#detail-panel"
        hx-swap="innerHTML"
    >
        <div class="flex items-start justify-between">
            <h4 class="font-medium text-gray-900 text-sm">{ item.Title }</h4>
            @PriorityBadge(item.Priority)
        </div>
        <p class="text-gray-500 text-xs mt-1 line-clamp-2">{ item.Description }</p>
        <div class="flex items-center justify-between mt-3">
            @StatusBadge(item.Status)
            <span class="text-xs text-gray-400">
                { item.CreatedAt.Format("Jan 2") }
            </span>
        </div>
    </div>
}
```

### Status Badges

```templ
func statusColor(status string) string {
    switch status {
    case "success", "merged", "completed":
        return "bg-green-100 text-green-800"
    case "running", "in_progress":
        return "bg-blue-100 text-blue-800"
    case "failed", "error":
        return "bg-red-100 text-red-800"
    case "pending", "waiting":
        return "bg-yellow-100 text-yellow-800"
    default:
        return "bg-gray-100 text-gray-800"
    }
}

templ StatusBadge(status string) {
    <span class={ "px-2 py-0.5 rounded-full text-xs font-medium", statusColor(status) }>
        if status == "running" {
            <span class="inline-block w-2 h-2 bg-blue-500 rounded-full animate-pulse mr-1"></span>
        }
        { status }
    </span>
}

templ PriorityBadge(priority string) {
    switch priority {
    case "high":
        <span class="text-red-500">
            @Icon("alert-circle", "w-4 h-4")
        </span>
    case "medium":
        <span class="text-yellow-500">
            @Icon("minus-circle", "w-4 h-4")
        </span>
    default:
        <span class="text-gray-400">
            @Icon("circle", "w-4 h-4")
        </span>
    }
}
```

---

## Data Tables

### Sortable Table

```templ
type Column struct {
    Key      string
    Label    string
    Sortable bool
}

templ DataTable(columns []Column, rows []map[string]any, sortBy string, sortDir string) {
    <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
                <tr>
                    for _, col := range columns {
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            if col.Sortable {
                                <button
                                    hx-get={ fmt.Sprintf("/api/table?sort=%s&dir=%s", col.Key, toggleDir(sortDir)) }
                                    hx-target="closest table"
                                    hx-swap="outerHTML"
                                    class="flex items-center gap-1 hover:text-gray-700"
                                >
                                    { col.Label }
                                    if sortBy == col.Key {
                                        if sortDir == "asc" {
                                            @Icon("chevron-up", "w-4 h-4")
                                        } else {
                                            @Icon("chevron-down", "w-4 h-4")
                                        }
                                    }
                                </button>
                            } else {
                                { col.Label }
                            }
                        </th>
                    }
                </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
                for _, row := range rows {
                    <tr class="hover:bg-gray-50">
                        for _, col := range columns {
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                { fmt.Sprint(row[col.Key]) }
                            </td>
                        }
                    </tr>
                }
            </tbody>
        </table>
    </div>
}

func toggleDir(dir string) string {
    if dir == "asc" {
        return "desc"
    }
    return "asc"
}
```

### With Search and Filter

```templ
templ TableWithControls(data TableData) {
    <div class="space-y-4">
        <div class="flex gap-4">
            <input
                type="search"
                name="q"
                placeholder="Search..."
                value={ data.Query }
                hx-get="/api/table"
                hx-trigger="keyup changed delay:300ms"
                hx-target="#table-container"
                hx-include="[name='status']"
                class="input w-64"
            />
            <select
                name="status"
                hx-get="/api/table"
                hx-trigger="change"
                hx-target="#table-container"
                hx-include="[name='q']"
                class="input w-40"
            >
                <option value="">All Status</option>
                <option value="active" selected?={ data.Status == "active" }>Active</option>
                <option value="pending" selected?={ data.Status == "pending" }>Pending</option>
                <option value="completed" selected?={ data.Status == "completed" }>Completed</option>
            </select>
        </div>
        <div id="table-container">
            @DataTable(data.Columns, data.Rows, data.SortBy, data.SortDir)
        </div>
    </div>
}
```

---

## Agent Control Panel

### Command Interface

```templ
type Command struct {
    Name        string
    Description string
    HasArgs     bool
}

var commands = []Command{
    {Name: "/status", Description: "Show current state"},
    {Name: "/daily-run", Description: "Execute daily workflow"},
    {Name: "/scout", Description: "Find new opportunities"},
    {Name: "/contribute", Description: "Execute contribution", HasArgs: true},
}

templ AgentControlPanel() {
    <div class="grid grid-cols-3 gap-6">
        <div class="col-span-1">
            @CommandSelector()
        </div>
        <div class="col-span-2">
            @OutputPanel()
        </div>
    </div>
}

templ CommandSelector() {
    <div class="bg-white rounded-lg shadow p-4">
        <h3 class="font-medium text-gray-900 mb-4">Run Command</h3>
        <form hx-post="/api/agent/start" hx-target="#output" hx-swap="innerHTML">
            <div class="space-y-2">
                for _, cmd := range commands {
                    <label class="flex items-start p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                        <input type="radio" name="command" value={ cmd.Name } class="mt-1"/>
                        <div class="ml-3">
                            <span class="font-mono text-sm">{ cmd.Name }</span>
                            <p class="text-xs text-gray-500">{ cmd.Description }</p>
                        </div>
                    </label>
                }
            </div>

            <div id="args-container" class="mt-4 hidden">
                <label class="block text-sm font-medium text-gray-700 mb-1">Arguments</label>
                <input type="text" name="args" class="input w-full" placeholder="e.g., issue URL"/>
            </div>

            <button type="submit" class="btn btn-primary w-full mt-4">
                <span class="htmx-indicator">
                    @Spinner()
                </span>
                <span class="htmx-hide-on-request">Run Command</span>
            </button>
        </form>
    </div>
}

templ OutputPanel() {
    <div class="bg-gray-900 rounded-lg shadow h-[600px] flex flex-col">
        <div class="flex items-center justify-between px-4 py-2 border-b border-gray-700">
            <span class="text-gray-400 text-sm">Output</span>
            <button
                hx-post="/api/agent/cancel"
                class="text-red-400 hover:text-red-300 text-sm"
            >
                Cancel
            </button>
        </div>
        <div
            id="output"
            class="flex-1 overflow-y-auto p-4 font-mono text-sm text-gray-300"
        >
            <span class="text-gray-500">Ready. Select a command to run.</span>
        </div>
    </div>
}
```

---

## Clawde Agent Streaming

### Stream Handler

```go
func handleAgentStream(w http.ResponseWriter, r *http.Request) {
    sse, err := NewSSEWriter(w)
    if err != nil {
        http.Error(w, err.Error(), 500)
        return
    }

    command := r.FormValue("command")
    args := r.FormValue("args")

    prompt := command
    if args != "" {
        prompt += " " + args
    }

    client := clawde.NewClient(
        clawde.WithModel("claude-sonnet-4-20250514"),
        clawde.WithSystemPrompt(loadSystemPrompt()),
        clawde.WithMaxTurns(50),
    )

    ctx := r.Context()
    stream, err := client.Query(ctx, prompt)
    if err != nil {
        sse.SendHTML("error", renderError(err.Error()))
        return
    }

    for stream.Next() {
        msg := stream.Current()

        switch m := msg.(type) {
        case *clawde.AssistantMessage:
            for _, block := range m.Content {
                switch b := block.(type) {
                case *clawde.TextBlock:
                    sse.SendHTML("message", renderTextChunk(b.Text))
                case *clawde.ThinkingBlock:
                    sse.SendHTML("thinking", renderThinking(b.Text))
                }
            }

        case *clawde.ToolUseMessage:
            sse.SendHTML("tool", renderToolUse(m.Name, m.Input))

        case *clawde.ToolResultMessage:
            sse.SendHTML("result", renderToolResult(m.Name, m.Result))

        case *clawde.ResultMessage:
            sse.SendHTML("done", renderComplete(m))
        }
    }

    if err := stream.Err(); err != nil {
        sse.SendHTML("error", renderError(err.Error()))
    }
}
```

### Streaming Output Component

```templ
templ StreamingOutput() {
    <div
        hx-ext="sse"
        sse-connect="/api/agent/stream"
        class="space-y-2"
    >
        <div id="messages" sse-swap="message" hx-swap="beforeend">
            <!-- Text messages appear here -->
        </div>
        <div id="tools" sse-swap="tool" hx-swap="beforeend">
            <!-- Tool calls appear here -->
        </div>
        <div id="status" sse-swap="done" hx-swap="innerHTML">
            <!-- Final status -->
        </div>
    </div>
}

templ TextChunk(text string) {
    <span class="text-gray-300">{ text }</span>
}

templ ToolUseCard(name string, input string) {
    <div class="bg-gray-800 rounded p-3 my-2 border-l-4 border-blue-500">
        <div class="flex items-center gap-2 text-blue-400 text-sm">
            @Icon("terminal", "w-4 h-4")
            <span class="font-mono">{ name }</span>
            <span class="animate-pulse">Running...</span>
        </div>
        if input != "" {
            <pre class="mt-2 text-xs text-gray-500 overflow-x-auto">{ input }</pre>
        }
    </div>
}

templ ToolResultCard(name string, result string, success bool) {
    <div class={
        "bg-gray-800 rounded p-3 my-2 border-l-4",
        templ.KV("border-green-500", success),
        templ.KV("border-red-500", !success),
    }>
        <div class="flex items-center gap-2 text-sm">
            if success {
                @Icon("check-circle", "w-4 h-4 text-green-400")
            } else {
                @Icon("x-circle", "w-4 h-4 text-red-400")
            }
            <span class="font-mono text-gray-400">{ name }</span>
        </div>
        <pre class="mt-2 text-xs text-gray-500 overflow-x-auto max-h-40">{ result }</pre>
    </div>
}
```

---

## Real-time Status Dashboard

### Stats Cards

```templ
templ StatsGrid() {
    <div
        class="grid grid-cols-4 gap-4"
        hx-get="/api/stats"
        hx-trigger="load, every 30s"
        hx-swap="innerHTML"
    >
        @StatCard("Total Runs", "128", "up", "+12%")
        @StatCard("Success Rate", "94%", "up", "+2%")
        @StatCard("Active Agents", "3", "neutral", "")
        @StatCard("Queue Size", "7", "down", "-3")
    </div>
}

templ StatCard(label string, value string, trend string, change string) {
    <div class="bg-white rounded-lg shadow p-4">
        <p class="text-sm text-gray-500">{ label }</p>
        <div class="flex items-end justify-between mt-2">
            <span class="text-2xl font-bold text-gray-900">{ value }</span>
            if change != "" {
                <span class={
                    "text-sm flex items-center",
                    templ.KV("text-green-500", trend == "up"),
                    templ.KV("text-red-500", trend == "down"),
                    templ.KV("text-gray-400", trend == "neutral"),
                }>
                    if trend == "up" {
                        @Icon("trending-up", "w-4 h-4 mr-1")
                    } else if trend == "down" {
                        @Icon("trending-down", "w-4 h-4 mr-1")
                    }
                    { change }
                </span>
            }
        </div>
    </div>
}
```

### Activity Feed

```templ
templ ActivityFeed() {
    <div class="bg-white rounded-lg shadow">
        <div class="px-4 py-3 border-b border-gray-200">
            <h3 class="font-medium text-gray-900">Recent Activity</h3>
        </div>
        <div
            hx-ext="sse"
            sse-connect="/api/activity/stream"
            sse-swap="activity"
            hx-swap="afterbegin"
            class="divide-y divide-gray-100 max-h-96 overflow-y-auto"
        >
            <!-- Activity items appear here -->
        </div>
    </div>
}

templ ActivityItem(activity Activity) {
    <div class="px-4 py-3 flex items-start gap-3">
        <div class={ "w-8 h-8 rounded-full flex items-center justify-center", activityColor(activity.Type) }>
            @Icon(activityIcon(activity.Type), "w-4 h-4")
        </div>
        <div class="flex-1 min-w-0">
            <p class="text-sm text-gray-900">{ activity.Message }</p>
            <p class="text-xs text-gray-500 mt-1">{ activity.Time.Format("3:04 PM") }</p>
        </div>
    </div>
}
```

---

## Detail Panel

### Lazy-loaded Sections

```templ
templ ItemDetailPage(item Item) {
    @DashboardLayout(item.Title, "Pipeline") {
        <div class="grid grid-cols-3 gap-6">
            <div class="col-span-2 space-y-6">
                @ItemHeader(item)
                @WorkflowSection(item.ID)
                @FilesSection(item.ID)
            </div>
            <div class="space-y-6">
                @MetadataCard(item)
                @ActionsCard(item)
            </div>
        </div>
    }
}

templ WorkflowSection(itemID string) {
    <div class="bg-white rounded-lg shadow">
        <div class="px-4 py-3 border-b border-gray-200">
            <h3 class="font-medium">Workflow Steps</h3>
        </div>
        <div
            hx-get={ "/api/items/" + itemID + "/workflow" }
            hx-trigger="revealed"
            hx-swap="innerHTML"
            class="p-4"
        >
            @LoadingPlaceholder()
        </div>
    </div>
}

templ FilesSection(itemID string) {
    <div class="bg-white rounded-lg shadow">
        <div class="px-4 py-3 border-b border-gray-200">
            <h3 class="font-medium">Changed Files</h3>
        </div>
        <div
            hx-get={ "/api/items/" + itemID + "/files" }
            hx-trigger="revealed"
            hx-swap="innerHTML"
            class="p-4"
        >
            @LoadingPlaceholder()
        </div>
    </div>
}

templ LoadingPlaceholder() {
    <div class="animate-pulse space-y-3">
        <div class="h-4 bg-gray-200 rounded w-3/4"></div>
        <div class="h-4 bg-gray-200 rounded w-1/2"></div>
        <div class="h-4 bg-gray-200 rounded w-2/3"></div>
    </div>
}
```

---

## Notification Toast

### Toast Container

```templ
templ ToastContainer() {
    <div
        id="toast-container"
        class="fixed bottom-4 right-4 space-y-2 z-50"
        hx-ext="sse"
        sse-connect="/api/notifications"
        sse-swap="toast"
        hx-swap="beforeend"
    >
        <!-- Toasts appear here -->
    </div>
}

templ Toast(message string, variant string) {
    <div
        class={
            "p-4 rounded-lg shadow-lg max-w-sm transform transition-all duration-300",
            templ.KV("bg-green-500 text-white", variant == "success"),
            templ.KV("bg-red-500 text-white", variant == "error"),
            templ.KV("bg-blue-500 text-white", variant == "info"),
        }
        x-data="{ show: true }"
        x-show="show"
        x-init="setTimeout(() => show = false, 5000)"
        x-transition
    >
        <div class="flex items-center gap-3">
            @toastIcon(variant)
            <p class="text-sm">{ message }</p>
            <button @click="show = false" class="ml-auto">
                @Icon("x", "w-4 h-4")
            </button>
        </div>
    </div>
}
```

---

## Progress Indicators

### Step Progress

```templ
type Step struct {
    Name   string
    Status string // pending, running, completed, failed
}

templ StepProgress(steps []Step, currentStep int) {
    <div class="space-y-3">
        for i, step := range steps {
            <div class="flex items-center gap-3">
                <div class={
                    "w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium",
                    templ.KV("bg-green-500 text-white", step.Status == "completed"),
                    templ.KV("bg-blue-500 text-white animate-pulse", step.Status == "running"),
                    templ.KV("bg-red-500 text-white", step.Status == "failed"),
                    templ.KV("bg-gray-200 text-gray-500", step.Status == "pending"),
                }>
                    if step.Status == "completed" {
                        @Icon("check", "w-4 h-4")
                    } else if step.Status == "running" {
                        @Spinner()
                    } else if step.Status == "failed" {
                        @Icon("x", "w-4 h-4")
                    } else {
                        { fmt.Sprint(i + 1) }
                    }
                </div>
                <span class={
                    "text-sm",
                    templ.KV("text-gray-900 font-medium", step.Status == "running"),
                    templ.KV("text-gray-500", step.Status == "pending"),
                    templ.KV("text-green-600", step.Status == "completed"),
                    templ.KV("text-red-600", step.Status == "failed"),
                }>
                    { step.Name }
                </span>
            </div>
        }
    </div>
}
```

---

## Icon Component

```templ
templ Icon(name string, class string) {
    <svg class={ class }>
        <use href={ "/static/icons.svg#" + name }></use>
    </svg>
}
```

Using sprite sheet for icons. Create with:
```bash
npx @pqina/svg-sprite-generator --input ./icons/*.svg --output ./static/icons.svg
```

---

## Integration

This skill works with:
- **go-htmx-core**: Handler patterns
- **go-templ-components**: Component building
- **go-htmx-sse**: Real-time streaming
- **go-htmx-forms**: Form components
- **clawde SDK**: Agent orchestration

Reference this skill when building admin UIs and agent control panels.
