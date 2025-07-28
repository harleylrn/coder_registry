import { describe, it, expect } from "bun:test";
import {
  runTerraformApply,
  runTerraformInit,
  testRequiredVariables,
  findResourceInstance,
} from "~test";
import path from "path";

const moduleDir = path.resolve(__dirname);

const requiredVars = {
  agent_id: "dummy-agent-id",
};

describe("amazon-q module", async () => {
  await runTerraformInit(moduleDir);

  // 1. Required variables
  testRequiredVariables(moduleDir, requiredVars);

  // 2. agentapi module is created when install_agentapi is true
  it("creates agentapi module when install_agentapi is true", async () => {
    const state = await runTerraformApply(moduleDir, {
      ...requiredVars,
      install_agentapi: true,
    });
    
    // Check that agentapi module resources are created
    const agentapiScript = findResourceInstance(state, "coder_script", "agentapi");
    expect(agentapiScript).toBeDefined();
    expect(agentapiScript.agent_id).toBe(requiredVars.agent_id);
  });

  // 3. agentapi web app is created
  it("creates agentapi web app", async () => {
    const state = await runTerraformApply(moduleDir, requiredVars);
    const webApp = findResourceInstance(state, "coder_app", "agentapi_web");
    expect(webApp).toBeDefined();
    expect(webApp.agent_id).toBe(requiredVars.agent_id);
    expect(webApp.slug).toBe("amazon-q");
  });

  // 4. agentapi CLI app is created when cli_app is enabled
  it("creates agentapi CLI app", async () => {
    const state = await runTerraformApply(moduleDir, requiredVars);
    const cliApp = findResourceInstance(state, "coder_app", "agentapi_cli");
    expect(cliApp).toBeDefined();
    expect(cliApp.agent_id).toBe(requiredVars.agent_id);
    expect(cliApp.slug).toBe("amazon-q-cli");
  });

  // 5. coder_ai_task is created
  it("creates coder_ai_task resource", async () => {
    const state = await runTerraformApply(moduleDir, requiredVars);
    const aiTask = findResourceInstance(state, "coder_ai_task", "agentapi");
    expect(aiTask).toBeDefined();
  });

  // 6. Test variable name changes (no more experiment_ prefix)
  it("accepts variables without experiment_ prefix", async () => {
    const varsWithoutExperiment = {
      ...requiredVars,
      use_screen: false,
      use_tmux: true,
      report_tasks: true,
      auth_tarball: "test-tarball",
      pre_install_script: "echo pre-install",
      post_install_script: "echo post-install",
    };
    
    const state = await runTerraformApply(moduleDir, varsWithoutExperiment);
    expect(state).toBeDefined();
  });

  // 7. Test AgentAPI configuration
  it("configures AgentAPI with correct parameters", async () => {
    const state = await runTerraformApply(moduleDir, {
      ...requiredVars,
      install_agentapi: true,
      agentapi_version: "v0.2.3",
    });
    
    const agentapiScript = findResourceInstance(state, "coder_script", "agentapi");
    expect(agentapiScript.script).toContain("ARG_AGENTAPI_VERSION='v0.2.3'");
  });

  // Add more state-based tests as needed
});
