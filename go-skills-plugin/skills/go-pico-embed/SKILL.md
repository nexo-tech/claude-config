---
name: go-pico-embed
description: Single binary deployment with embedded static assets. CDN-first approach with Pico CSS and HTMX, optional local fallback for air-gapped deployments.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Go Embed + Pico CSS

Build single-binary Go web applications. Use CDN for CSS/JS (recommended), or embed locally for offline deployments. Zero Node.js dependencies.

## When to Use

- Deploying Go web apps as single binary
- Using Pico CSS via CDN (recommended)
- Need local asset fallback for air-gapped deployment
- Want zero-config deployment (just copy binary)

---

## CDN-First Strategy (Recommended)

For most deployments, use CDN links directly in templates:

```templ
templ Base(title string) {
    <!DOCTYPE html>
    <html lang="en" data-theme="light">
    <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>{ title }</title>
        <!-- Pico CSS from CDN (~10KB gzipped) -->
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"/>
        <!-- Custom overrides (optional, embedded) -->
        <link rel="stylesheet" href="/static/css/custom.css"/>
    </head>
    <body>
        { children... }
        <!-- HTMX from CDN (~15KB gzipped) -->
        <script src="https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js"></script>
    </body>
    </html>
}
```

### Benefits

- Zero embed overhead for CSS/JS
- CDN caching worldwide (fast loads)
- Version pinning for stability
- Smaller binary size
- No build pipeline needed

---

## Go Embed Basics

### Embed Directive

```go
// embed.go
package main

import "embed"

//go:embed all:static
var staticFS embed.FS
```

### Single File

```go
import _ "embed"

//go:embed static/css/custom.css
var customCSS []byte
```

### Multiple Patterns

```go
//go:embed static/css/*.css
//go:embed static/images/*
var staticFS embed.FS
```

The `all:` prefix includes files starting with `_` or `.`.

---

## Project Structure

```
project/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   └── handlers/
├── views/
│   ├── layouts/
│   │   └── base.templ      # CDN links here
│   ├── pages/
│   └── components/
├── static/
│   └── css/
│       └── custom.css      # Only custom overrides
├── .air.toml
├── go.mod
└── Makefile
```

**What to embed:**
- Custom CSS overrides
- Your own images/icons
- Favicon
- Any app-specific assets

**What NOT to embed (use CDN):**
- Pico CSS (~10KB gzipped via CDN)
- HTMX (~15KB gzipped via CDN)
- System fonts (Pico uses system fonts by default)

---

## Serving Embedded Files

### Basic Setup

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

func main() {
    mux := http.NewServeMux()

    // Serve static files
    sub, _ := fs.Sub(staticFS, "static")
    mux.Handle("GET /static/", http.StripPrefix("/static/",
        http.FileServer(http.FS(sub))))

    // Routes
    mux.HandleFunc("GET /", handleHome)

    log.Println("Server on :8080")
    http.ListenAndServe("localhost:8080", mux)
}
```

### With Cache Headers

```go
func staticHandler() http.Handler {
    sub, _ := fs.Sub(staticFS, "static")
    fs := http.FileServer(http.FS(sub))

    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Cache static assets for 1 year (use versioning to bust cache)
        w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
        fs.ServeHTTP(w, r)
    })
}
```

---

## Local Embed Strategy (Air-Gapped)

For offline or air-gapped deployments, download and embed libraries:

### Download Assets

```bash
mkdir -p static/css static/js

# Download Pico CSS
curl -o static/css/pico.min.css \
    https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css

# Download HTMX
curl -o static/js/htmx.min.js \
    https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js

# Optional: HTMX SSE extension
curl -o static/js/sse.js \
    https://cdn.jsdelivr.net/npm/htmx-ext-sse@2.2.2/sse.js
```

### Update Template for Local Files

```templ
templ Base(title string) {
    <!DOCTYPE html>
    <html lang="en" data-theme="light">
    <head>
        <meta charset="UTF-8"/>
        <title>{ title }</title>
        <!-- Local files (embedded in binary) -->
        <link rel="stylesheet" href="/static/css/pico.min.css"/>
        <link rel="stylesheet" href="/static/css/custom.css"/>
    </head>
    <body>
        { children... }
        <script src="/static/js/htmx.min.js"></script>
    </body>
    </html>
}
```

### Binary Size Impact

| Embedded Assets | Additional Size |
|-----------------|-----------------|
| Custom CSS only (~2KB) | +2 KB |
| + Pico CSS (~80KB) | +80 KB |
| + HTMX (~50KB) | +50 KB |
| Total | ~132 KB |

Negligible impact on a ~5MB Go binary.

---

## Environment-Aware Assets

Switch between CDN and local based on environment:

### Config Struct

```go
// config/config.go
package config

import "os"

type Config struct {
    UseCDN bool
    Port   string
}

func Load() Config {
    return Config{
        UseCDN: os.Getenv("USE_CDN") != "false",
        Port:   getEnv("PORT", "8080"),
    }
}

func getEnv(key, fallback string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return fallback
}
```

### Template with Config

```templ
package layouts

type AssetConfig struct {
    UseCDN bool
}

var (
    PicoCDN = "https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"
    HtmxCDN = "https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js"
)

templ Base(title string, cfg AssetConfig) {
    <!DOCTYPE html>
    <html lang="en" data-theme="light">
    <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>{ title }</title>
        if cfg.UseCDN {
            <link rel="stylesheet" href={ PicoCDN }/>
        } else {
            <link rel="stylesheet" href="/static/css/pico.min.css"/>
        }
        <link rel="stylesheet" href="/static/css/custom.css"/>
    </head>
    <body>
        { children... }
        if cfg.UseCDN {
            <script src={ HtmxCDN }></script>
        } else {
            <script src="/static/js/htmx.min.js"></script>
        }
    </body>
    </html>
}
```

### Usage

```bash
# Production (CDN)
./server

# Air-gapped (local files)
USE_CDN=false ./server
```

---

## Custom CSS File

Create `static/css/custom.css` for overrides:

```css
/* HTMX Loading Indicators */
.htmx-indicator {
    display: none;
}

.htmx-request .htmx-indicator {
    display: inline-block;
}

.htmx-request.htmx-indicator {
    display: inline-block;
}

.htmx-request .htmx-hide-on-request {
    display: none;
}

/* Optional: Pico CSS variable overrides */
:root {
    /* Custom primary color */
    /* --pico-primary: #0ea5e9; */

    /* Custom border radius */
    /* --pico-border-radius: 0.5rem; */

    /* Custom font */
    /* --pico-font-family: system-ui, sans-serif; */
}

/* Optional: Force dark mode */
/*
[data-theme="dark"] {
    --pico-background-color: #11191f;
}
*/
```

---

## Makefile

```makefile
.PHONY: dev build clean deps download-assets

# Development with hot reload
dev:
	@air

# Build production binary
build:
	@templ generate
	@CGO_ENABLED=0 go build -ldflags="-s -w" -o bin/server ./cmd/server
	@echo "Built: bin/server"
	@ls -lh bin/server

# Install Go tools
deps:
	@go install github.com/a-h/templ/cmd/templ@latest
	@go install github.com/air-verse/air@latest
	@go mod tidy

# Download assets for air-gapped deployment
download-assets:
	@mkdir -p static/css static/js
	@curl -sL -o static/css/pico.min.css \
	    https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css
	@curl -sL -o static/js/htmx.min.js \
	    https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js
	@echo "Downloaded Pico CSS and HTMX to static/"

# Clean build artifacts
clean:
	@rm -rf bin/ tmp/
	@find . -name '*_templ.go' -delete
```

---

## Dockerfile

No Node.js required - much smaller image!

```dockerfile
# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install Templ
RUN go install github.com/a-h/templ/cmd/templ@latest

# Copy dependency files
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build
RUN templ generate
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o server ./cmd/server

# Runtime stage
FROM alpine:latest

WORKDIR /app

# Copy binary and static files
COPY --from=builder /app/server .
COPY --from=builder /app/static ./static

EXPOSE 8080

CMD ["./server"]
```

### Image Size Comparison

| Approach | Image Size |
|----------|------------|
| Go + Pico (CDN) | ~15 MB |
| Go + Tailwind (Node.js build) | ~200+ MB |

---

## Binary Size Comparison

| Configuration | Binary Size |
|--------------|-------------|
| Go only (CDN assets) | ~5 MB |
| + embedded custom CSS | ~5 MB |
| + embedded Pico + HTMX | ~5.2 MB |

With `ldflags="-s -w"` (strips debug info).

---

## Asset Fingerprinting (Optional)

For cache busting on custom assets:

```go
// assets.go
package main

import (
    "crypto/md5"
    "encoding/hex"
    "io/fs"
    "path/filepath"
)

var assetHashes = make(map[string]string)

func init() {
    fs.WalkDir(staticFS, "static", func(path string, d fs.DirEntry, err error) error {
        if err != nil || d.IsDir() {
            return err
        }
        data, _ := staticFS.ReadFile(path)
        hash := md5.Sum(data)
        // Store: "css/custom.css" -> "a1b2c3d4"
        rel, _ := filepath.Rel("static", path)
        assetHashes[rel] = hex.EncodeToString(hash[:8])
        return nil
    })
}

// AssetURL returns versioned URL: /static/css/custom.css?v=a1b2c3d4
func AssetURL(path string) string {
    if hash, ok := assetHashes[path]; ok {
        return "/static/" + path + "?v=" + hash
    }
    return "/static/" + path
}
```

### Template Usage

```templ
templ Base(title string) {
    <head>
        <link rel="stylesheet" href={ AssetURL("css/custom.css") }/>
    </head>
}
```

---

## Development vs Production Assets

```go
// main.go
package main

import (
    "embed"
    "io/fs"
    "os"
)

//go:embed all:static
var embeddedFS embed.FS

func getStaticFS() fs.FS {
    if os.Getenv("ENV") == "development" {
        // Serve from disk (supports live editing)
        return os.DirFS("static")
    }
    // Serve embedded (production)
    sub, _ := fs.Sub(embeddedFS, "static")
    return sub
}
```

In development, edit `static/css/custom.css` and refresh to see changes immediately.

---

## Integration

This skill works with:
- **go-project-bootstrap**: Initial project setup
- **go-htmx-core**: Handler patterns
- **go-templ-components**: Template rendering
- **go-htmx-sse**: Real-time features

Reference this skill when deploying Go web applications.
