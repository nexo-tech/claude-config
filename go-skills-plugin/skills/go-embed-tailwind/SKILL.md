---
name: go-embed-tailwind
description: Single binary deployment with embedded static assets, Tailwind CSS, and go:generate build pipeline.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Go Embed + Tailwind CSS

Build single-binary Go web applications with embedded static assets and Tailwind CSS.

## When to Use

- Deploying Go web apps as single binary
- Using Tailwind CSS with Go templates
- Need reproducible builds without external dependencies
- Want zero-config deployment (just copy binary)

---

## Project Structure

```
project/
├── main.go
├── embed.go              # embed directives
├── handlers/
├── templates/
│   └── *.templ
├── static/
│   ├── css/
│   │   └── tailwind.css  # generated
│   ├── js/
│   │   └── htmx.min.js
│   └── images/
├── tailwind.config.js
├── input.css             # Tailwind input
├── package.json
├── air.toml
├── Makefile
└── go.mod
```

---

## Go Embed Basics

### Single File

```go
import _ "embed"

//go:embed static/htmx.min.js
var htmxJS []byte
```

### Directory

```go
import "embed"

//go:embed static/*
var staticFS embed.FS
```

### Multiple Patterns

```go
//go:embed static/css/*.css
//go:embed static/js/*.js
//go:embed static/images/*
var staticFS embed.FS
```

### All Files Including Subdirectories

```go
//go:embed all:static
var staticFS embed.FS
```

The `all:` prefix includes files starting with `_` or `.`.

---

## Embed File (`embed.go`)

Keep embed directives in a dedicated file:

```go
// embed.go
package main

import "embed"

//go:embed all:static
var staticFS embed.FS

//go:embed templates
var templatesFS embed.FS
```

---

## Serving Embedded Files

### Basic File Server

```go
func main() {
    mux := http.NewServeMux()

    // Serve static files
    staticHandler := http.FileServer(http.FS(staticFS))
    mux.Handle("GET /static/", staticHandler)

    // ...
}
```

### Strip Prefix

If your embed has a directory prefix:

```go
//go:embed static
var staticFS embed.FS

// Files are at staticFS/static/css/tailwind.css
// But we want /css/tailwind.css

sub, _ := fs.Sub(staticFS, "static")
mux.Handle("GET /", http.FileServer(http.FS(sub)))
```

### Custom Handler with Caching

```go
func staticHandler() http.Handler {
    sub, _ := fs.Sub(staticFS, "static")
    fs := http.FileServer(http.FS(sub))

    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Cache static assets for 1 year
        w.Header().Set("Cache-Control", "public, max-age=31536000")
        fs.ServeHTTP(w, r)
    })
}
```

---

## Tailwind CSS Setup

### Install Tailwind

```bash
npm init -y
npm install -D tailwindcss
npx tailwindcss init
```

### tailwind.config.js

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./templates/**/*.templ",
    "./templates/**/*.go",  // generated templ files
  ],
  theme: {
    extend: {
      colors: {
        // Custom colors
        brand: {
          50: '#f0f9ff',
          500: '#0ea5e9',
          900: '#0c4a6e',
        },
      },
    },
  },
  plugins: [],
}
```

### Input CSS (input.css)

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Custom component classes */
@layer components {
  .btn {
    @apply px-4 py-2 font-medium rounded-md transition-colors;
  }
  .btn-primary {
    @apply bg-blue-600 text-white hover:bg-blue-700;
  }
  .btn-secondary {
    @apply bg-gray-200 text-gray-800 hover:bg-gray-300;
  }
  .card {
    @apply bg-white rounded-lg shadow-md p-4 border border-gray-200;
  }
  .input {
    @apply w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500;
  }
}

/* HTMX loading states */
@layer utilities {
  .htmx-indicator {
    display: none;
  }
  .htmx-request .htmx-indicator {
    display: inline-block;
  }
  .htmx-request.htmx-indicator {
    display: inline-block;
  }
}
```

### package.json Scripts

```json
{
  "scripts": {
    "build:css": "tailwindcss -i ./input.css -o ./static/css/tailwind.css --minify",
    "watch:css": "tailwindcss -i ./input.css -o ./static/css/tailwind.css --watch",
    "dev": "concurrently \"npm run watch:css\" \"air\""
  },
  "devDependencies": {
    "tailwindcss": "^3.4.0",
    "concurrently": "^8.0.0"
  }
}
```

---

## go:generate Integration

### Using go:generate

```go
// main.go
package main

//go:generate npm run build:css
//go:generate templ generate

func main() {
    // ...
}
```

Run before build:
```bash
go generate ./...
go build -o app
```

### Makefile (Recommended)

```makefile
.PHONY: build dev clean generate

# Build production binary
build: generate
	go build -o bin/app .

# Generate assets
generate:
	npm run build:css
	templ generate

# Development with hot reload
dev:
	npm run dev

# Clean build artifacts
clean:
	rm -rf bin/ tmp/
	find . -name '*_templ.go' -delete

# Install dependencies
deps:
	go mod download
	npm install
	go install github.com/a-h/templ/cmd/templ@latest
	go install github.com/air-verse/air@latest
```

---

## Hot Reload Development

### Air Configuration (air.toml)

```toml
root = "."
tmp_dir = "tmp"

[build]
  # Build command: generate templ then compile Go
  cmd = "templ generate && go build -o ./tmp/main ."
  bin = "./tmp/main"
  delay = 500

  # Watch these extensions
  include_ext = ["go", "templ", "css"]

  # Exclude these directories
  exclude_dir = ["tmp", "node_modules", "static/css"]

  # Exclude generated files
  exclude_regex = ["_templ\\.go$"]

[screen]
  clear_on_rebuild = true

[misc]
  clean_on_exit = true
```

### Development Workflow

Terminal 1 - CSS watcher:
```bash
npm run watch:css
```

Terminal 2 - Go watcher:
```bash
air
```

Or combined:
```bash
npm run dev
```

---

## Production Build

### Build Script

```bash
#!/bin/bash
# build.sh

set -e

echo "Building CSS..."
npm run build:css

echo "Generating templates..."
templ generate

echo "Building binary..."
CGO_ENABLED=0 go build -ldflags="-s -w" -o bin/app .

echo "Done! Binary at bin/app"
ls -lh bin/app
```

### Dockerfile

```dockerfile
# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install Node for Tailwind
RUN apk add --no-cache nodejs npm

# Install Go tools
RUN go install github.com/a-h/templ/cmd/templ@latest

# Copy dependency files
COPY go.mod go.sum ./
COPY package*.json ./

# Install dependencies
RUN go mod download
RUN npm ci

# Copy source
COPY . .

# Build
RUN npm run build:css
RUN templ generate
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app/bin/app .

# Runtime stage
FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/bin/app .

EXPOSE 8080

CMD ["./app"]
```

Result: ~10-20MB container with single binary.

---

## Asset Fingerprinting (Optional)

For cache busting, add content hash to filenames.

### Hash Function

```go
// assets.go
package main

import (
    "crypto/md5"
    "encoding/hex"
    "io/fs"
)

var assetHashes = make(map[string]string)

func init() {
    fs.WalkDir(staticFS, "static", func(path string, d fs.DirEntry, err error) error {
        if err != nil || d.IsDir() {
            return err
        }
        data, _ := staticFS.ReadFile(path)
        hash := md5.Sum(data)
        assetHashes[path] = hex.EncodeToString(hash[:8])
        return nil
    })
}

func AssetPath(path string) string {
    if hash, ok := assetHashes["static/"+path]; ok {
        // /css/tailwind.css -> /css/tailwind.abc123.css
        ext := filepath.Ext(path)
        base := path[:len(path)-len(ext)]
        return "/" + base + "." + hash + ext
    }
    return "/" + path
}
```

### Template Helper

```templ
templ Base(title string) {
    <!DOCTYPE html>
    <html>
    <head>
        <link rel="stylesheet" href={ AssetPath("css/tailwind.css") }/>
        <script src={ AssetPath("js/htmx.min.js") }></script>
    </head>
    // ...
}
```

### Serve with Hash Stripping

```go
func staticHandler() http.Handler {
    sub, _ := fs.Sub(staticFS, "static")
    fs := http.FileServer(http.FS(sub))

    // Regex to strip hash: /css/tailwind.abc123.css -> /css/tailwind.css
    hashPattern := regexp.MustCompile(`\.([a-f0-9]{16})\.`)

    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Strip hash from path
        path := hashPattern.ReplaceAllString(r.URL.Path, ".")
        r.URL.Path = path

        // Long cache for hashed assets
        if hashPattern.MatchString(r.URL.Path) {
            w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
        }

        fs.ServeHTTP(w, r)
    })
}
```

---

## HTMX Integration

### Download HTMX

```bash
curl -o static/js/htmx.min.js https://unpkg.com/htmx.org@2.0.4/dist/htmx.min.js
```

### SSE Extension

```bash
curl -o static/js/sse.js https://unpkg.com/htmx-ext-sse@2.2.2/sse.js
```

### Base Template

```templ
templ Base(title string) {
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>{ title }</title>
        <link rel="stylesheet" href="/static/css/tailwind.css"/>
    </head>
    <body class="bg-gray-50 min-h-screen">
        { children... }

        <script src="/static/js/htmx.min.js"></script>
        <script src="/static/js/sse.js"></script>
    </body>
    </html>
}
```

---

## Environment-Aware Assets

### Development vs Production

```go
var (
    //go:embed static
    embeddedFS embed.FS

    isDev = os.Getenv("ENV") == "development"
)

func getStaticFS() fs.FS {
    if isDev {
        // Serve from disk in dev (supports hot reload)
        return os.DirFS("static")
    }
    // Serve embedded in production
    sub, _ := fs.Sub(embeddedFS, "static")
    return sub
}
```

### Main Setup

```go
func main() {
    mux := http.NewServeMux()

    staticFS := getStaticFS()
    mux.Handle("GET /static/", http.StripPrefix("/static/",
        http.FileServer(http.FS(staticFS))))

    // ...
}
```

---

## Complete Example

### Project Files

**main.go**:
```go
package main

import (
    "embed"
    "io/fs"
    "log"
    "net/http"
)

//go:embed all:static
var staticFS embed.FS

//go:generate npm run build:css
//go:generate templ generate

func main() {
    mux := http.NewServeMux()

    // Static files
    sub, _ := fs.Sub(staticFS, "static")
    mux.Handle("GET /static/", http.StripPrefix("/static/",
        http.FileServer(http.FS(sub))))

    // Pages
    mux.HandleFunc("GET /", handleHome)

    log.Println("Server starting on :8080")
    http.ListenAndServe(":8080", mux)
}

func handleHome(w http.ResponseWriter, r *http.Request) {
    HomePage().Render(r.Context(), w)
}
```

**templates/home.templ**:
```templ
package main

templ HomePage() {
    <!DOCTYPE html>
    <html>
    <head>
        <title>Home</title>
        <link rel="stylesheet" href="/static/css/tailwind.css"/>
        <script src="/static/js/htmx.min.js"></script>
    </head>
    <body class="bg-gray-50">
        <main class="container mx-auto px-4 py-8">
            <h1 class="text-3xl font-bold text-gray-900">Hello World</h1>
            <button class="btn btn-primary mt-4">Click Me</button>
        </main>
    </body>
    </html>
}
```

### Build Commands

```bash
# Development
make dev

# Production build
make build

# Run production binary
./bin/app
```

---

## Binary Size Optimization

### Build Flags

```bash
# Strip debug info
go build -ldflags="-s -w" -o app .

# With UPX compression (optional)
upx --best app
```

### Typical Sizes

| Component | Size |
|-----------|------|
| Base Go binary | ~8 MB |
| With Tailwind CSS (~50KB) | ~8 MB |
| With HTMX (~15KB) | ~8 MB |
| After ldflags -s -w | ~5 MB |
| After UPX | ~2 MB |

---

## Integration

This skill works with:
- **go-htmx-core**: Handler patterns
- **go-templ-components**: Template rendering
- **go-htmx-sse**: Real-time features
- **go-htmx-forms**: Form styling

Reference this skill when setting up a new Go + HTMX project.
