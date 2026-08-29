import { createGodotWebBridge, registerGuaWebMcp } from "gua-webmcp";

declare global {
  interface Window {
    __guaGodotWebPort?: unknown;
    __guaWebMcpRegistration?: Awaited<ReturnType<typeof registerGuaWebMcp>>;
  }
}

const statusId = "gua-webmcp-status";

function setStatus(message: string, supported: boolean): void {
  let element = document.getElementById(statusId);
  if (!element) {
    element = document.createElement("div");
    element.id = statusId;
    element.setAttribute("role", "status");
    Object.assign(element.style, {
      position: "fixed",
      right: "12px",
      bottom: "10px",
      zIndex: "9999",
      padding: "6px 10px",
      borderRadius: "6px",
      background: "rgba(5, 11, 18, .82)",
      color: supported ? "#68f7a1" : "#7897a5",
      font: "12px system-ui, sans-serif",
      pointerEvents: "none",
    });
    document.body.appendChild(element);
  }
  element.textContent = message;
}

async function waitForGodotPort(timeoutMs = 30_000): Promise<void> {
  const deadline = performance.now() + timeoutMs;
  while (!window.__guaGodotWebPort) {
    if (performance.now() >= deadline) {
      throw new Error("Gua Godot Web port did not become ready.");
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
}

async function start(): Promise<void> {
  try {
    await waitForGodotPort();
    const registration = await registerGuaWebMcp(createGodotWebBridge());
    window.__guaWebMcpRegistration = registration;
    if (registration.supported) {
      setStatus("Gua WebMCP ready · Player profile", true);
    } else {
      setStatus("WebMCP unavailable · game remains playable", false);
      console.info("Gua WebMCP is not supported in this browser:", registration.error);
    }
  } catch (error) {
    setStatus("Gua bridge unavailable · game remains playable", false);
    console.warn("Gua WebMCP bootstrap failed:", error);
  }
}

void start();

