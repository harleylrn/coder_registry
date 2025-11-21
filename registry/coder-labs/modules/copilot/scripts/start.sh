#!/bin/bash
set -euo pipefail

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ARG_WORKDIR=${ARG_WORKDIR:-"$HOME"}
ARG_AI_PROMPT=$(echo -n "${ARG_AI_PROMPT:-}" | base64 -d 2>/dev/null || echo "")
ARG_SYSTEM_PROMPT=$(echo -n "${ARG_SYSTEM_PROMPT:-}" | base64 -d 2>/dev/null || echo "")
ARG_COPILOT_MODEL=${ARG_COPILOT_MODEL:-}
ARG_ALLOW_ALL_TOOLS=${ARG_ALLOW_ALL_TOOLS:-false}
ARG_ALLOW_TOOLS=${ARG_ALLOW_TOOLS:-}
ARG_DENY_TOOLS=${ARG_DENY_TOOLS:-}
ARG_TRUSTED_DIRECTORIES=${ARG_TRUSTED_DIRECTORIES:-}
ARG_EXTERNAL_AUTH_ID=${ARG_EXTERNAL_AUTH_ID:-github}
ARG_RESUME_SESSION=${ARG_RESUME_SESSION:-true}

validate_copilot_installation() {
  if ! command_exists copilot; then
    echo "ERROR: Copilot not installed. Run: npm install -g @github/copilot"
    exit 1
  fi
}

build_ai_prompt() {
  local ai_prompt=""

  if [ -n "$ARG_AI_PROMPT" ]; then
    ai_prompt=$(printf '%s' "$ARG_AI_PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n' | sed 's/\\n$//')
  fi

  echo "$ai_prompt"
}

build_copilot_args() {
  COPILOT_ARGS=()

  if [ "$ARG_ALLOW_ALL_TOOLS" = "true" ]; then
    COPILOT_ARGS+=(--allow-all-tools)
  fi

  if [ -n "$ARG_ALLOW_TOOLS" ]; then
    IFS=',' read -ra ALLOW_ARRAY <<<"$ARG_ALLOW_TOOLS"
    for tool in "${ALLOW_ARRAY[@]}"; do
      if [ -n "$tool" ]; then
        COPILOT_ARGS+=(--allow-tool "$tool")
      fi
    done
  fi

  if [ -n "$ARG_DENY_TOOLS" ]; then
    IFS=',' read -ra DENY_ARRAY <<<"$ARG_DENY_TOOLS"
    for tool in "${DENY_ARRAY[@]}"; do
      if [ -n "$tool" ]; then
        COPILOT_ARGS+=(--deny-tool "$tool")
      fi
    done
  fi
}

check_existing_session() {
  if [ "$ARG_RESUME_SESSION" = "true" ]; then
    if copilot --help >/dev/null 2>&1; then
      local session_dir="$HOME/.copilot/history-session-state"
      if [ -d "$session_dir" ] && [ -n "$(ls "$session_dir"/session_*_*.json 2>/dev/null)" ]; then
        echo "Found existing Copilot session. Will continue latest session." >&2
        return 0
      fi
    fi
  fi
  return 1
}

start_agentapi() {
  echo "Starting in directory: $ARG_WORKDIR"
  cd "$ARG_WORKDIR"

  build_copilot_args
  echo "Starting new Copilot session..."
  local ai_prompt
  ai_prompt=$(build_ai_prompt)

  if [ -n "$ai_prompt" ]; then
    echo "Using initial prompt with system context"
    if [ ${#COPILOT_ARGS[@]} -gt 0 ]; then
      echo "Copilot arguments: ${COPILOT_ARGS[*]}"
      agentapi server -I="$ai_prompt" --term-width 120 --term-height 40 -- copilot "${COPILOT_ARGS[@]}"
    else
      agentapi server -I="$ai_prompt" --term-width 120 --term-height 40 -- copilot
    fi
  else
    if [ ${#COPILOT_ARGS[@]} -gt 0 ]; then
      echo "Copilot arguments: ${COPILOT_ARGS[*]}"
      agentapi server --term-width 120 --term-height 40 -- copilot "${COPILOT_ARGS[@]}"
    else
      agentapi server --term-width 120 --term-height 40 -- copilot
    fi
  fi
  # fi
}

validate_copilot_installation
start_agentapi
