terraform {
  required_version = ">= 1.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.7"
    }
  }
}

variable "agent_id" {
  type        = string
  description = "The ID of a Coder agent."
}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

variable "order" {
  type        = number
  description = "The order determines the position of app in the UI presentation. The lowest order is shown first and apps with equal order are sorted by name (ascending order)."
  default     = null
}

variable "group" {
  type        = string
  description = "The name of a group that this app belongs to."
  default     = null
}

variable "icon" {
  type        = string
  description = "The icon to use for the app."
  default     = "/icon/amazon-q.svg"
}

variable "folder" {
  type        = string
  description = "The folder to run Amazon Q in."
  default     = "/home/coder"
}

variable "install_amazon_q" {
  type        = bool
  description = "Whether to install Amazon Q."
  default     = true
}

variable "amazon_q_version" {
  type        = string
  description = "The version of Amazon Q to install."
  default     = "latest"
}

variable "install_agentapi" {
  type        = bool
  description = "Whether to install AgentAPI."
  default     = true
}

variable "agentapi_version" {
  type        = string
  description = "The version of AgentAPI to install."
  default     = "v0.2.3"
}

variable "use_screen" {
  type        = bool
  description = "Whether to use screen for running Amazon Q in the background."
  default     = false
}

variable "use_tmux" {
  type        = bool
  description = "Whether to use tmux instead of screen for running Amazon Q in the background."
  default     = false
}

variable "report_tasks" {
  type        = bool
  description = "Whether to enable task reporting."
  default     = false
}

variable "pre_install_script" {
  type        = string
  description = "Custom script to run before installing Amazon Q."
  default     = null
}

variable "post_install_script" {
  type        = string
  description = "Custom script to run after installing Amazon Q."
  default     = null
}

variable "auth_tarball" {
  type        = string
  description = "Base64 encoded, zstd compressed tarball of a pre-authenticated ~/.local/share/amazon-q directory. After running `q login` on another machine, you may generate it with: `cd ~/.local/share/amazon-q && tar -c . | zstd | base64 -w 0`"
  default     = "tarball"
}

variable "system_prompt" {
  type        = string
  description = "The system prompt to use for Amazon Q. This should instruct the agent how to do task reporting."
  default     = <<-EOT
    You are a helpful Coding assistant. Aim to autonomously investigate
    and solve issues the user gives you and test your work, whenever possible.
    Avoid shortcuts like mocking tests. When you get stuck, you can ask the user
    but opt for autonomy.

    YOU MUST REPORT ALL TASKS TO CODER.
    When reporting tasks, you MUST follow these EXACT instructions:
    - IMMEDIATELY report status after receiving ANY user message.
    - Be granular. If you are investigating with multiple steps, report each step to coder.

    Task state MUST be one of the following:
    - Use "state": "working" when actively processing WITHOUT needing additional user input.
    - Use "state": "complete" only when finished with a task.
    - Use "state": "failure" when you need ANY user input, lack sufficient details, or encounter blockers.

    Task summaries MUST:
    - Include specifics about what you're doing.
    - Include clear and actionable steps for the user.
    - Be less than 160 characters in length.
  EOT
}

variable "ai_prompt" {
  type        = string
  description = "The initial task prompt to send to Amazon Q."
  default     = "Please help me with my coding tasks. I'll provide specific instructions as needed."
}

locals {
  app_slug        = "amazon-q"
  module_dir_name = ".amazon-q-module"
  
  # Create the start script for Amazon Q
  start_script = <<-EOT
    #!/bin/bash
    set -e
    
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    
    cd ${var.folder}
    
    # Check if Amazon Q is installed
    if ! command -v q >/dev/null 2>&1; then
      echo "Error: Amazon Q is not installed. Please enable install_amazon_q or install it manually."
      exit 1
    fi
    
    # If tmux or screen is enabled, attach to existing session or start new one
    if [ "${var.use_tmux}" = "true" ]; then
      if tmux has-session -t amazon-q 2>/dev/null; then
        echo "Attaching to existing Amazon Q tmux session..."
        exec tmux attach-session -t amazon-q
      else
        echo "Starting new Amazon Q tmux session..."
        exec tmux new-session -s amazon-q -c ${var.folder} "q chat --trust-all-tools"
      fi
    elif [ "${var.use_screen}" = "true" ]; then
      if screen -list | grep -q "amazon-q"; then
        echo "Attaching to existing Amazon Q screen session..."
        exec screen -xRR amazon-q
      else
        echo "Starting new Amazon Q screen session..."
        exec screen -S amazon-q bash -c 'cd ${var.folder} && q chat --trust-all-tools'
      fi
    else
      # Direct execution for AgentAPI
      echo "Starting Amazon Q chat..."
      exec q chat --trust-all-tools
    fi
  EOT

  
  # Create the install script for Amazon Q
  install_script = <<-EOT
    #!/bin/bash
    set -o errexit
    set -o pipefail

    command_exists() {
      command -v "$1" >/dev/null 2>&1
    }

    if [ "$ARG_INSTALL_AMAZON_Q" = "true" ]; then
      echo "Installing Amazon Q..."
      PREV_DIR="$PWD"
      TMP_DIR="$(mktemp -d)"
      cd "$TMP_DIR"

      ARCH="$(uname -m)"
      case "$ARCH" in
        "x86_64")
          Q_URL="https://desktop-release.q.us-east-1.amazonaws.com/$ARG_AMAZON_Q_VERSION/q-x86_64-linux.zip"
          ;;
        "aarch64"|"arm64")
          Q_URL="https://desktop-release.codewhisperer.us-east-1.amazonaws.com/$ARG_AMAZON_Q_VERSION/q-aarch64-linux.zip"
          ;;
        *)
          echo "Error: Unsupported architecture: $ARCH. Amazon Q only supports x86_64 and arm64."
          exit 1
          ;;
      esac

      echo "Downloading Amazon Q for $ARCH..."
      curl --proto '=https' --tlsv1.2 -sSf "$Q_URL" -o "q.zip"
      unzip q.zip
      ./q/install.sh --no-confirm
      cd "$PREV_DIR"
      export PATH="$PATH:$HOME/.local/bin"
      echo "Installed Amazon Q version: $(q --version)"
    fi

    echo "Extracting auth tarball..."
    PREV_DIR="$PWD"
    echo "$ARG_AUTH_TARBALL" | base64 -d > /tmp/auth.tar.zst
    rm -rf ~/.local/share/amazon-q
    mkdir -p ~/.local/share/amazon-q
    cd ~/.local/share/amazon-q
    tar -I zstd -xf /tmp/auth.tar.zst
    rm /tmp/auth.tar.zst
    cd "$PREV_DIR"
    echo "Extracted auth tarball"

    if [ "$ARG_REPORT_TASKS" = "true" ]; then
      echo "Configuring Amazon Q to report tasks via Coder MCP..."
      q mcp add --name coder --command "coder" --args "exp,mcp,server,--allowed-tools,coder_report_task" --env "CODER_MCP_APP_STATUS_SLUG=amazon-q,CODER_MCP_AI_AGENTAPI_URL=http://localhost:3284" --scope global --force
      echo "Added Coder MCP server to Amazon Q configuration"
    fi

    if [ "$ARG_USE_TMUX" = "true" ] && [ "$ARG_USE_SCREEN" = "true" ]; then
      echo "Error: Both use_tmux and use_screen cannot be true simultaneously."
      echo "Please set only one of them to true."
      exit 1
    fi

    if [ "$ARG_USE_TMUX" = "true" ]; then
      echo "Running Amazon Q in the background with tmux..."

      if ! command_exists tmux; then
        echo "Error: tmux is not installed. Please install tmux manually."
        exit 1
      fi

      touch "$HOME/.amazon-q.log"

      export LANG=en_US.UTF-8
      export LC_ALL=en_US.UTF-8

      tmux new-session -d -s amazon-q -c "$ARG_FOLDER" "q chat --trust-all-tools | tee -a \"$HOME/.amazon-q.log\" && exec bash"

      if [ -n "$ARG_AI_PROMPT" ]; then
        tmux send-keys -t amazon-q "$ARG_AI_PROMPT"
        sleep 5
        tmux send-keys -t amazon-q Enter
      fi
    fi

    if [ "$ARG_USE_SCREEN" = "true" ]; then
      echo "Running Amazon Q in the background..."

      if ! command_exists screen; then
        echo "Error: screen is not installed. Please install screen manually."
        exit 1
      fi

      touch "$HOME/.amazon-q.log"

      if [ ! -f "$HOME/.screenrc" ]; then
        echo "Creating ~/.screenrc and adding multiuser settings..." | tee -a "$HOME/.amazon-q.log"
        echo -e "multiuser on\\nacladd $(whoami)" > "$HOME/.screenrc"
      fi

      if ! grep -q "^multiuser on$" "$HOME/.screenrc"; then
        echo "Adding 'multiuser on' to ~/.screenrc..." | tee -a "$HOME/.amazon-q.log"
        echo "multiuser on" >> "$HOME/.screenrc"
      fi

      if ! grep -q "^acladd $(whoami)$" "$HOME/.screenrc"; then
        echo "Adding 'acladd $(whoami)' to ~/.screenrc..." | tee -a "$HOME/.amazon-q.log"
        echo "acladd $(whoami)" >> "$HOME/.screenrc"
      fi
      export LANG=en_US.UTF-8
      export LC_ALL=en_US.UTF-8

      screen -U -dmS amazon-q bash -c "
        cd $ARG_FOLDER
        q chat --trust-all-tools | tee -a \"$HOME/.amazon-q.log\"
        exec bash
      "
      
      if [ -n "$ARG_AI_PROMPT" ]; then
        # Send the prompt to the screen session
        screen -S amazon-q -X stuff "$ARG_AI_PROMPT"
        sleep 5
        screen -S amazon-q -X stuff "^M"
      fi
    fi
  EOT
}

module "agentapi" {
  source  = "registry.coder.com/coder/agentapi/coder"
  version = "1.0.0"

  agent_id             = var.agent_id
  web_app_slug         = local.app_slug
  web_app_order        = var.order
  web_app_group        = var.group
  web_app_icon         = var.icon
  web_app_display_name = "Amazon Q"
  cli_app              = true
  cli_app_slug         = "${local.app_slug}-cli"
  cli_app_display_name = "Amazon Q CLI"
  cli_app_icon         = var.icon
  module_dir_name      = local.module_dir_name
  install_agentapi     = var.install_agentapi
  agentapi_version     = var.agentapi_version
  pre_install_script   = var.pre_install_script
  post_install_script  = var.post_install_script
  start_script         = local.start_script
  install_script       = <<-EOT
    #!/bin/bash
    set -o errexit
    set -o pipefail

    echo -n '${base64encode(local.install_script)}' | base64 -d > /tmp/install.sh
    chmod +x /tmp/install.sh

    ARG_INSTALL_AMAZON_Q='${var.install_amazon_q}' \
    ARG_AMAZON_Q_VERSION='${var.amazon_q_version}' \
    ARG_AUTH_TARBALL='${var.auth_tarball}' \
    ARG_REPORT_TASKS='${var.report_tasks}' \
    ARG_USE_TMUX='${var.use_tmux}' \
    ARG_USE_SCREEN='${var.use_screen}' \
    ARG_FOLDER='${var.folder}' \
    ARG_AI_PROMPT='${var.ai_prompt}' \
    /tmp/install.sh
  EOT
}
