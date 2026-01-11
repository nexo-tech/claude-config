---
name: go-templ-components
description: Type-safe Templ templates for Go web applications. JSX-like syntax with compile-time error checking.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Go Templ Components

Build type-safe, composable UI components using Templ. Catch template errors at compile time, not runtime.

## When to Use

- Building Go web applications with templates
- Need type-safe template rendering
- Want JSX-like component syntax
- Prefer compile-time errors over runtime panics

---

## Setup

### Install Templ CLI

```bash
go install github.com/a-h/templ/cmd/templ@latest
```

### Add to Project

```bash
go get github.com/a-h/templ
```

### VS Code Extension

Install `templ-vscode` for syntax highlighting and LSP support.

---

## File Organization

```
templates/
├── layouts/
│   └── base.templ       # Main layout wrapper
├── pages/
│   ├── home.templ       # Full page components
│   └── dashboard.templ
├── partials/
│   ├── header.templ     # Shared sections
│   ├── nav.templ
│   └── footer.templ
└── components/
    ├── button.templ     # Reusable UI components
    ├── card.templ
    ├── badge.templ
    └── form/
        ├── input.templ
        └── select.templ
```

---

## Basic Syntax

### Simple Component

```templ
// templates/components/greeting.templ
package components

templ Greeting(name string) {
    <h1>Hello, { name }!</h1>
}
```

### Expressions

Use `{ }` for Go expressions:

```templ
templ UserCard(user User) {
    <div class="card">
        <h2>{ user.Name }</h2>
        <p>{ user.Email }</p>
        <span>Joined { user.CreatedAt.Format("Jan 2, 2006") }</span>
        <span>{ fmt.Sprintf("%d posts", user.PostCount) }</span>
    </div>
}
```

### Conditionals

```templ
templ Alert(message string, isError bool) {
    if isError {
        <div class="alert alert-error">{ message }</div>
    } else {
        <div class="alert alert-info">{ message }</div>
    }
}

templ UserStatus(user User) {
    switch user.Role {
        case "admin":
            <span class="badge-red">Admin</span>
        case "mod":
            <span class="badge-blue">Moderator</span>
        default:
            <span class="badge-gray">User</span>
    }
}
```

### Loops

```templ
templ ItemList(items []Item) {
    <ul>
        for _, item := range items {
            <li>{ item.Name }</li>
        }
    </ul>
}

templ Table(rows []Row) {
    <table>
        for i, row := range rows {
            <tr class={ templ.KV("bg-gray-50", i%2 == 0) }>
                <td>{ row.Name }</td>
            </tr>
        }
    </table>
}
```

---

## CSS Class Helpers

### Dynamic Classes with templ.KV

```templ
templ Button(text string, primary bool, disabled bool) {
    <button
        class={
            "btn",
            templ.KV("btn-primary", primary),
            templ.KV("btn-secondary", !primary),
            templ.KV("opacity-50 cursor-not-allowed", disabled),
        }
        disabled?={ disabled }
    >
        { text }
    </button>
}
```

### Using templ.Classes

```templ
templ Card(highlight bool) {
    <div class={ templ.Classes("card", "p-4", map[string]bool{
        "border-blue-500": highlight,
        "border-gray-200": !highlight,
    }) }>
        { children... }
    </div>
}
```

### Computed Class Function

```templ
func statusClass(status string) string {
    switch status {
    case "success":
        return "bg-green-100 text-green-800"
    case "error":
        return "bg-red-100 text-red-800"
    case "pending":
        return "bg-yellow-100 text-yellow-800"
    default:
        return "bg-gray-100 text-gray-800"
    }
}

templ StatusBadge(status string) {
    <span class={ "badge", statusClass(status) }>
        { status }
    </span>
}
```

---

## Component Composition

### Calling Components

Use `@` to render other components:

```templ
templ HomePage(user User, items []Item) {
    @Header()
    <main>
        @UserCard(user)
        @ItemList(items)
    </main>
    @Footer()
}
```

### Children (Slots)

Accept children using `templ.Component` or `{ children... }`:

```templ
// Card that wraps content
templ Card(title string) {
    <div class="card">
        <h3 class="card-title">{ title }</h3>
        <div class="card-body">
            { children... }
        </div>
    </div>
}

// Usage
templ Dashboard() {
    @Card("User Stats") {
        <p>Total users: 1,234</p>
        <p>Active today: 89</p>
    }
}
```

### Named Slots via Component Parameter

```templ
templ Modal(title string, footer templ.Component) {
    <div class="modal">
        <div class="modal-header">{ title }</div>
        <div class="modal-body">
            { children... }
        </div>
        <div class="modal-footer">
            @footer
        </div>
    </div>
}

// Usage
templ DeleteConfirm(itemID string) {
    @Modal("Confirm Delete", modalFooter(itemID)) {
        <p>Are you sure you want to delete this item?</p>
    }
}

templ modalFooter(itemID string) {
    <button hx-delete={ "/items/" + itemID }>Delete</button>
    <button onclick="closeModal()">Cancel</button>
}
```

---

## Layouts

### Base Layout

```templ
// templates/layouts/base.templ
package layouts

templ Base(title string) {
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>{ title }</title>
        <link rel="stylesheet" href="/static/css/tailwind.css"/>
        <script src="/static/htmx.min.js"></script>
    </head>
    <body class="bg-gray-50">
        @Nav()
        <main class="container mx-auto px-4 py-8">
            { children... }
        </main>
        @Footer()
    </body>
    </html>
}
```

### Page Using Layout

```templ
// templates/pages/home.templ
package pages

import "myapp/templates/layouts"
import "myapp/templates/components"

templ HomePage(user User, items []Item) {
    @layouts.Base("Home") {
        <h1 class="text-2xl font-bold mb-4">Welcome, { user.Name }</h1>

        <div class="grid grid-cols-3 gap-4">
            for _, item := range items {
                @components.ItemCard(item)
            }
        </div>
    }
}
```

---

## HTMX Fragments

Create components that work as HTMX response fragments.

```templ
// Full page with layout
templ ItemsPage(items []Item) {
    @layouts.Base("Items") {
        <div id="items-container">
            @ItemsList(items)
        </div>
    }
}

// Fragment for HTMX (no layout wrapper)
templ ItemsList(items []Item) {
    for _, item := range items {
        @ItemCard(item)
    }
}

// Single item fragment
templ ItemCard(item Item) {
    <div id={ "item-" + item.ID } class="card">
        <h3>{ item.Name }</h3>
        <button
            hx-delete={ "/items/" + item.ID }
            hx-target={ "#item-" + item.ID }
            hx-swap="outerHTML"
        >
            Delete
        </button>
    </div>
}
```

### Handler Pattern

```go
func handleItems(w http.ResponseWriter, r *http.Request) {
    items := getItems()

    if r.Header.Get("HX-Request") == "true" {
        // HTMX request: return fragment only
        templates.ItemsList(items).Render(r.Context(), w)
    } else {
        // Browser request: return full page
        templates.ItemsPage(items).Render(r.Context(), w)
    }
}
```

---

## Attributes

### Boolean Attributes

```templ
templ Checkbox(label string, checked bool, disabled bool) {
    <label>
        <input
            type="checkbox"
            checked?={ checked }
            disabled?={ disabled }
        />
        { label }
    </label>
}
```

### Spread Attributes

```templ
templ Input(attrs templ.Attributes) {
    <input class="input" { attrs... }/>
}

// Usage
@Input(templ.Attributes{
    "type": "email",
    "name": "email",
    "placeholder": "Enter email",
    "required": true,
})
```

### Dynamic Attributes

```templ
templ Link(href string, external bool) {
    <a
        href={ templ.SafeURL(href) }
        if external {
            target="_blank"
            rel="noopener noreferrer"
        }
    >
        { children... }
    </a>
}
```

---

## Scripts and Styles

### Inline Script

```templ
templ WithScript() {
    <div id="counter">0</div>
    <script>
        document.getElementById('counter').onclick = function() {
            this.textContent = parseInt(this.textContent) + 1;
        }
    </script>
}
```

### Script Component (Deduplicated)

```templ
// Only included once even if component used multiple times
script chartInit() {
    window.initChart = function(el) {
        // Chart initialization
    }
}

templ Chart(data []Point) {
    @chartInit()
    <canvas id="chart" onload="initChart(this)"></canvas>
}
```

### CSS Component

```templ
css cardStyles() {
    .custom-card {
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
}

templ StyledCard() {
    @cardStyles()
    <div class="custom-card">
        { children... }
    </div>
}
```

---

## Raw HTML

When you need to render trusted HTML:

```templ
templ MarkdownContent(html string) {
    <div class="prose">
        @templ.Raw(html)
    </div>
}
```

**Warning**: Only use with trusted/sanitized content. Never use with user input.

---

## Error Handling in Templates

### Showing Errors

```templ
templ FormField(name string, value string, err string) {
    <div class="field">
        <label>{ name }</label>
        <input
            name={ strings.ToLower(name) }
            value={ value }
            class={ templ.KV("border-red-500", err != "") }
        />
        if err != "" {
            <span class="text-red-500 text-sm">{ err }</span>
        }
    </div>
}
```

### Error Page

```templ
templ ErrorPage(code int, message string) {
    @layouts.Base(fmt.Sprintf("Error %d", code)) {
        <div class="text-center py-20">
            <h1 class="text-6xl font-bold text-gray-300">{ fmt.Sprintf("%d", code) }</h1>
            <p class="text-xl text-gray-600 mt-4">{ message }</p>
            <a href="/" class="btn btn-primary mt-8">Go Home</a>
        </div>
    }
}
```

---

## Build Workflow

### Generate Go Files

```bash
templ generate
```

This creates `*_templ.go` files next to your `.templ` files.

### Watch Mode

```bash
templ generate --watch
```

### With Air (Hot Reload)

`air.toml`:
```toml
[build]
  cmd = "templ generate && go build -o ./tmp/main ."
  bin = "tmp/main"
  include_ext = ["go", "templ"]
  exclude_dir = ["tmp", "node_modules"]
```

---

## Type Safety Examples

### Struct Props

```templ
type CardProps struct {
    Title       string
    Description string
    ImageURL    string
    Link        string
    Tags        []string
}

templ Card(props CardProps) {
    <div class="card">
        <img src={ props.ImageURL } alt={ props.Title }/>
        <h3>{ props.Title }</h3>
        <p>{ props.Description }</p>
        <div class="tags">
            for _, tag := range props.Tags {
                <span class="tag">{ tag }</span>
            }
        </div>
        <a href={ templ.SafeURL(props.Link) }>Read more</a>
    </div>
}
```

### Enum-like Types

```templ
type ButtonVariant string

const (
    ButtonPrimary   ButtonVariant = "primary"
    ButtonSecondary ButtonVariant = "secondary"
    ButtonDanger    ButtonVariant = "danger"
)

func (v ButtonVariant) Class() string {
    switch v {
    case ButtonPrimary:
        return "bg-blue-600 text-white"
    case ButtonSecondary:
        return "bg-gray-200 text-gray-800"
    case ButtonDanger:
        return "bg-red-600 text-white"
    default:
        return "bg-gray-200"
    }
}

templ Button(text string, variant ButtonVariant) {
    <button class={ "btn", variant.Class() }>
        { text }
    </button>
}
```

---

## Common Patterns

### Icon Component

```templ
templ Icon(name string, size string) {
    <svg class={ "icon", "icon-" + size }>
        <use href={ "/static/icons.svg#" + name }></use>
    </svg>
}

// Usage
@Icon("trash", "sm")
@Icon("edit", "md")
```

### Empty State

```templ
templ EmptyState(title string, description string) {
    <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400">...</svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">{ title }</h3>
        <p class="mt-1 text-sm text-gray-500">{ description }</p>
        { children... }
    </div>
}

// Usage
@EmptyState("No items", "Get started by creating a new item.") {
    <button class="btn btn-primary mt-4">Create Item</button>
}
```

### Loading Skeleton

```templ
templ SkeletonCard() {
    <div class="card animate-pulse">
        <div class="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
        <div class="h-4 bg-gray-200 rounded w-1/2"></div>
    </div>
}

templ ItemsListWithLoading(items []Item, loading bool) {
    if loading {
        for i := 0; i < 3; i++ {
            @SkeletonCard()
        }
    } else {
        for _, item := range items {
            @ItemCard(item)
        }
    }
}
```

---

## Integration

This skill works with:
- **go-htmx-core**: HTMX attributes and patterns
- **go-htmx-sse**: Real-time streaming components
- **go-htmx-forms**: Form components with validation
- **go-embed-tailwind**: CSS class utilities

Reference this skill when writing any `.templ` file.
