#!/usr/bin/env bash
# ============================================================
# claude-copilot - Start Copilot API and launch Claude Code
# ============================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-1234}"
MODEL="${MODEL:-claude-sonnet-4.6}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}▶${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn()    { echo -e "${YELLOW}!${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }

# ============================================================
# Step 1: Check dependencies
# ============================================================
check_dependencies() {
  log_info "Checking dependencies..."

  # Check bun
  if command -v bun &> /dev/null; then
    log_success "bun found: $(bun --version)"
  else
    log_error "bun not found. Installing..."
    npm install -g bun
    log_success "bun installed"
  fi

  # Check node_modules
  if [[ ! -d "$SCRIPT_DIR/node_modules" ]]; then
    log_info "Installing dependencies..."
    cd "$SCRIPT_DIR" && bun install
    log_success "Dependencies installed"
  else
    log_success "Dependencies already installed"
  fi
}

# ============================================================
# Step 2: Check authentication
# ============================================================
check_auth() {
  log_info "Checking GitHub authentication..."

  TOKEN_DIR="$HOME/.local/share/copilot-api"
  STATE_FILE="$TOKEN_DIR/state.json"

  if [[ -f "$STATE_FILE" ]]; then
    log_success "Already authenticated"
  else
    log_warn "Not authenticated, running GitHub auth flow..."
    cd "$SCRIPT_DIR" && bun run ./src/main.ts auth
    log_success "Authentication completed"
  fi
}

# ============================================================
# Step 3: Start the server
# ============================================================
start_server() {
  log_info "Starting Copilot API server on port $PORT..."

  # Check if port is already in use
  if lsof -i :$PORT &> /dev/null; then
    log_warn "Port $PORT is already in use"
    log_info "Using existing server at http://localhost:$PORT"
    return 0
  fi

  # Start server in background
  cd "$SCRIPT_DIR"
  nohup bun run ./src/main.ts start --port "$PORT" > "$SCRIPT_DIR/server.log" 2>&1 &
  SERVER_PID=$!
  echo $SERVER_PID > "$SCRIPT_DIR/.server.pid"

  # Wait for server to start
  log_info "Waiting for server to start..."
  for i in {1..30}; do
    if curl -s "http://localhost:$PORT/v1/models" &> /dev/null; then
      log_success "Server started successfully at http://localhost:$PORT"
      return 0
    fi
    sleep 1
  done

  log_error "Server failed to start. Check logs: $SCRIPT_DIR/server.log"
  return 1
}

# ============================================================
# Step 4: Launch Claude with Copilot configuration
# ============================================================
launch_claude() {
  log_info "Launching Claude Code with Copilot API..."

  if command -v claude &> /dev/null; then
    ANTHROPIC_AUTH_TOKEN="copilot-api" \
    ANTHROPIC_BASE_URL="http://localhost:$PORT/v1" \
    ANTHROPIC_MODEL="$MODEL" \
    API_TIMEOUT_MS="300000" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1" \
    claude "$@"
  else
    log_error "Claude Code not found. Please install with: npm install -g @anthropic-ai/claude-code"
    exit 1
  fi
}

# ============================================================
# Main
# ============================================================
main() {
  echo ""
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║           claude-copilot - Copilot API + Claude        │"
  echo "╚════════════════════════════════════════════════════════╝"
  echo ""

  check_dependencies
  check_auth
  start_server
  launch_claude "$@"
}

main "$@"
