---
display_name: Amazon Q
description: Run Amazon Q in your workspace to access Amazon's AI coding assistant with AgentAPI integration.
icon: ../../../../.icons/amazon-q.svg
maintainer_github: coder
verified: true
tags: [agent, ai, aws, amazon-q, agentapi]
---

# Amazon Q

Run [Amazon Q](https://aws.amazon.com/q/) in your workspace to access Amazon's AI coding assistant. This module installs and launches Amazon Q with AgentAPI integration, providing both web and CLI interfaces for enhanced AI-powered development.

```tf
module "amazon-q" {
  source   = "registry.coder.com/coder/amazon-q/coder"
  version  = "1.2.0"
  agent_id = coder_agent.example.id
  # Required: see below for how to generate
  auth_tarball = var.amazon_q_auth_tarball
}
```

![Amazon-Q in action](../../.images/amazon-q.png)

## Prerequisites

- You must generate an authenticated Amazon Q tarball on another machine:
  ```sh
  cd ~/.local/share/amazon-q && tar -c . | zstd | base64 -w 0
  ```
  Paste the result into the `auth_tarball` variable.
- To run in the background, your workspace must have `screen` or `tmux` installed.

<details>
<summary><strong>How to generate the Amazon Q auth tarball (step-by-step)</strong></summary>

**1. Install and authenticate Amazon Q on your local machine:**

- Download and install Amazon Q from the [official site](https://aws.amazon.com/q/developer/).
- Run `q login` and complete the authentication process in your terminal.

**2. Locate your Amazon Q config directory:**

- The config is typically stored at `~/.local/share/amazon-q`.

**3. Generate the tarball:**

- Run the following command in your terminal:
  ```sh
  cd ~/.local/share/amazon-q
  tar -c . | zstd | base64 -w 0
  ```

**4. Copy the output:**

- The command will output a long string. Copy this entire string.

**5. Paste into your Terraform variable:**

- Assign the string to the `auth_tarball` variable in your Terraform configuration, for example:
  ```tf
  variable "amazon_q_auth_tarball" {
    type    = string
    default = "PASTE_LONG_STRING_HERE"
  }
  ```

**Note:**

- You must re-generate the tarball if you log out or re-authenticate Amazon Q on your local machine.
- This process is required for each user who wants to use Amazon Q in their workspace.

[Reference: Amazon Q documentation](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/generate-docs.html)

</details>

## Features

- **AgentAPI Integration**: Provides both web and CLI interfaces
- **Task Reporting**: Automatic task reporting to Coder via MCP
- **Background Execution**: Support for tmux and screen
- **Flexible Installation**: Configurable Amazon Q and AgentAPI versions
- **Custom Scripts**: Pre and post-install script support

## Examples

### Basic usage with AgentAPI

```tf
module "amazon-q" {
  source                = "registry.coder.com/coder/amazon-q/coder"
  version               = "1.2.0"
  agent_id              = coder_agent.example.id
  auth_tarball          = var.amazon_q_auth_tarball
  install_agentapi      = true
  report_tasks          = true
}
```

### Run Amazon Q in the background with tmux

```tf
module "amazon-q" {
  source       = "registry.coder.com/coder/amazon-q/coder"
  version      = "1.2.0"
  agent_id     = coder_agent.example.id
  auth_tarball = var.amazon_q_auth_tarball
  use_tmux     = true
}
```

### Disable AgentAPI and use traditional approach

```tf
module "amazon-q" {
  source           = "registry.coder.com/coder/amazon-q/coder"
  version          = "1.2.0"
  agent_id         = coder_agent.example.id
  auth_tarball     = var.amazon_q_auth_tarball
  install_agentapi = false
}
```

### Run custom scripts before/after install

```tf
module "amazon-q" {
  source              = "registry.coder.com/coder/amazon-q/coder"
  version             = "1.2.0"
  agent_id            = coder_agent.example.id
  auth_tarball        = var.amazon_q_auth_tarball
  pre_install_script  = "echo Pre-install!"
  post_install_script = "echo Post-install!"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| agent_id | The ID of a Coder agent | `string` | n/a | yes |
| auth_tarball | Base64 encoded, zstd compressed tarball of authenticated Amazon Q directory | `string` | `"tarball"` | no |
| install_amazon_q | Whether to install Amazon Q | `bool` | `true` | no |
| amazon_q_version | The version of Amazon Q to install | `string` | `"latest"` | no |
| install_agentapi | Whether to install AgentAPI | `bool` | `true` | no |
| agentapi_version | The version of AgentAPI to install | `string` | `"v0.2.3"` | no |
| use_screen | Whether to use screen for background execution | `bool` | `false` | no |
| use_tmux | Whether to use tmux for background execution | `bool` | `false` | no |
| report_tasks | Whether to enable task reporting | `bool` | `false` | no |
| pre_install_script | Custom script to run before installing Amazon Q | `string` | `null` | no |
| post_install_script | Custom script to run after installing Amazon Q | `string` | `null` | no |
| system_prompt | The system prompt to use for Amazon Q | `string` | See main.tf | no |
| ai_prompt | The initial task prompt to send to Amazon Q | `string` | Default greeting | no |
| folder | The folder to run Amazon Q in | `string` | `"/home/coder"` | no |
| order | The order of the app in UI presentation | `number` | `null` | no |
| group | The name of a group that this app belongs to | `string` | `null` | no |
| icon | The icon to use for the app | `string` | `"/icon/amazon-q.svg"` | no |

## Breaking Changes from v1.1.0

- **Variable Names**: Removed `experiment_` prefix from all variables:
  - `experiment_use_screen` → `use_screen`
  - `experiment_use_tmux` → `use_tmux`
  - `experiment_report_tasks` → `report_tasks`
  - `experiment_pre_install_script` → `pre_install_script`
  - `experiment_post_install_script` → `post_install_script`
  - `experiment_auth_tarball` → `auth_tarball`

- **AgentAPI Integration**: Now uses the agentapi module for enhanced functionality
- **New Variables**: Added `install_agentapi` and `agentapi_version`
- **Enhanced MCP**: Improved MCP integration with AgentAPI URL support

## Notes

- Only one of `use_screen` or `use_tmux` can be true at a time.
- If neither is set, Amazon Q runs in the foreground via AgentAPI.
- AgentAPI provides both web interface and CLI access.
- Task reporting requires `report_tasks = true` and proper MCP configuration.
- For more details, see the [main.tf](./main.tf) source.
