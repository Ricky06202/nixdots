const API = "/jan-api/v1";
const API_KEY = "jan-local";
const STORAGE_KEY = "jan-remoto-chat-v1";
const MODELS = {
  "spark-4b": { label: "Spark 4B · local", temperature: 0.7, top_p: 0.95 },
};
const SYSTEM_PROMPT = "Eres Spark, un asistente local. Responde en el idioma del usuario, de forma clara y natural. Esta pantalla es solo para conversar: no afirmes haber ejecutado comandos ni editado archivos. Si recibes una imagen, analízala con atención.";
const $ = (selector) => document.querySelector(selector);

const sidebar = $("#sidebar");
const backdrop = $("#backdrop");
const historyEl = $("#chat-history");
const messagesEl = $("#messages");
const welcomeEl = $("#welcome");
const promptEl = $("#prompt-input");
const modelSelect = $("#model-select");
const sendButton = $("#send-button");
const statusDot = $("#status-dot");
const statusText = $("#status-text");
const attachmentBox = $("#attachment");
const attachmentImage = $("#attachment-image");
const attachmentName = $("#attachment-name");
const photoInput = $("#photo-input");

function makeId() {
  return globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function loadChats() {
  try {
    const value = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "[]");
    return Array.isArray(value) ? value : [];
  } catch {
    return [];
  }
}

let chats = loadChats();
let activeId = chats[0]?.id ?? null;
let pendingPhoto = null;
let activeRequest = null;
let currentAssistantNodes = null;

function getChat() {
  return chats.find((chat) => chat.id === activeId) ?? null;
}

function persist() {
  // Store conversation text on this phone, never the attached image bytes.
  const saved = chats.slice(0, 16).map((chat) => ({
    id: chat.id,
    title: chat.title,
    model: chat.model,
    updatedAt: chat.updatedAt,
    messages: chat.messages.slice(-32).map((message) => ({
      role: message.role,
      text: message.text,
      hasImage: Boolean(message.hasImage),
      speed: message.speed ?? null,
      reasoning: (message.reasoning ?? "").slice(0, 4000),
    })),
  }));
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(saved));
  } catch {
    showToast("No hay espacio para guardar más historial en este teléfono.");
  }
}

function setStatus(ready, text) {
  statusText.textContent = text;
  statusDot.classList.toggle("online", ready);
  statusDot.classList.toggle("offline", !ready);
}

function showToast(text) {
  const toast = $("#toast");
  toast.textContent = text;
  toast.classList.add("show");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.remove("show"), 4200);
}

function closeSidebar() {
  sidebar.classList.remove("open");
  backdrop.classList.remove("open");
}

function renderHistory() {
  historyEl.replaceChildren();
  for (const chat of chats) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `history-item${chat.id === activeId ? " active" : ""}`;
    const icon = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    icon.setAttribute("viewBox", "0 0 24 24");
    icon.setAttribute("aria-hidden", "true");
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("d", "M7 4.5h10A2.5 2.5 0 0 1 19.5 7v10a2.5 2.5 0 0 1-2.5 2.5H7A2.5 2.5 0 0 1 4.5 17V7A2.5 2.5 0 0 1 7 4.5ZM8 9h8M8 12.5h6");
    icon.append(path);
    const label = document.createElement("span");
    label.textContent = chat.title || "Nuevo chat";
    button.append(icon, label);
    button.addEventListener("click", () => {
      activeId = chat.id;
      modelSelect.value = chat.model in MODELS ? chat.model : "spark-4b";
      render();
      closeSidebar();
    });
    historyEl.append(button);
  }
}

function renderMessage(message, index) {
  const row = document.createElement("article");
  row.className = `message ${message.role}${message.error ? " message-error" : ""}`;
  const avatar = document.createElement("div");
  avatar.className = "message-avatar";
  if (message.role === "assistant") {
    const image = document.createElement("img");
    image.src = "/jan-remoto-icon-192.png";
    image.alt = "Jan";
    avatar.append(image);
  } else {
    avatar.textContent = "Tú";
  }

  const body = document.createElement("div");
  body.className = "message-body";
  const label = document.createElement("p");
  label.className = "message-label";
  label.textContent = message.role === "assistant" ? "JAN" : "TÚ";
  body.append(label);

  if (message.imageData) {
    const image = document.createElement("img");
    image.className = "message-image";
    image.src = message.imageData;
    image.alt = "Foto adjunta";
    body.append(image);
  } else if (message.hasImage) {
    const placeholder = document.createElement("div");
    placeholder.className = "image-placeholder";
    placeholder.textContent = "Foto adjunta (no guardada en el historial local)";
    body.append(placeholder);
  }

  // TwIL (reasoning_format=deepseek) streams the whole thought process in
  // `reasoning_content`; the final answer arrives later in `content`.
  let reasoningText = null;
  if (message.reasoning) {
    const details = document.createElement("details");
    details.className = "reasoning";
    details.open = Boolean(message.streaming);
    const summary = document.createElement("summary");
    summary.textContent = message.streaming ? "Razonando…" : "Razonamiento";
    const reasoning = document.createElement("div");
    reasoning.className = "reasoning-text";
    reasoning.textContent = message.reasoning;
    details.append(summary, reasoning);
    body.append(details);
    reasoningText = reasoning;
  }

  const text = document.createElement("div");
  text.className = "message-text";
  text.textContent = message.text || "";
  text.dataset.messageIndex = String(index);
  body.append(text);
  let thinkingNode = null;
  if (message.streaming && !message.text && !message.reasoning) {
    thinkingNode = document.createElement("div");
    thinkingNode.className = "typing-indicator";
    thinkingNode.innerHTML = "<i></i><i></i><i></i><span>Jan está pensando</span>";
    body.append(thinkingNode);
  }
  if (message.speed) {
    const speed = document.createElement("div");
    speed.className = "message-speed";
    speed.textContent = `${message.speed.toFixed(1)} tokens/s`;
    body.append(speed);
  }
  row.append(avatar, body);
  return { row, text, reasoning: reasoningText, thinking: thinkingNode };
}

function render() {
  renderHistory();
  const chat = getChat();
  if (!chat) return;
  modelSelect.value = chat.model in MODELS ? chat.model : "spark-4b";
  welcomeEl.hidden = chat.messages.length > 0;
  messagesEl.replaceChildren();
  const list = document.createElement("div");
  list.className = "message-list";
  chat.messages.forEach((message, index) => list.append(renderMessage(message, index).row));
  messagesEl.append(list);
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

async function checkJan(showMessage = true) {
  try {
    const response = await fetch(`${API}/models`, {
      headers: { Authorization: `Bearer ${API_KEY}` },
      cache: "no-store",
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body.error?.message || `HTTP ${response.status}`);
    const available = new Set((body.data ?? []).map((model) => model.id));
    if (!available.has("spark-4b")) throw new Error("Falta el modelo");
    setStatus(true, "Jan local listo");
    return true;
  } catch {
    setStatus(false, "Jan desconectado");
    if (showMessage) showToast("Ejecuta 'local-ai chat' en el PC y vuelve a intentar.");
    return false;
  }
}

function readDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(reader.error ?? new Error("No se pudo leer la foto"));
    reader.readAsDataURL(file);
  });
}

function clearPendingPhoto() {
  pendingPhoto = null;
  photoInput.value = "";
  attachmentImage.removeAttribute("src");
  attachmentName.textContent = "";
  attachmentBox.hidden = true;
}

function apiMessage(message) {
  if (message.role === "user" && message.imageData) {
    return {
      role: "user",
      content: [
        { type: "text", text: message.text },
        { type: "image_url", image_url: { url: message.imageData } },
      ],
    };
  }
  return { role: message.role, content: message.text || "" };
}

function updateAssistantText(text) {
  if (!currentAssistantNodes?.text) return;
  currentAssistantNodes.text.textContent = text;
  if (currentAssistantNodes.thinking) {
    currentAssistantNodes.thinking.remove();
    currentAssistantNodes.thinking = null;
  }
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

function ensureReasoningNode() {
  const body = currentAssistantNodes?.text?.closest(".message-body");
  if (!body) return null;
  let node = body.querySelector(".reasoning-text");
  if (node) return node;
  const details = document.createElement("details");
  details.className = "reasoning";
  details.open = true;
  const summary = document.createElement("summary");
  summary.textContent = "Razonando…";
  node = document.createElement("div");
  node.className = "reasoning-text";
  details.append(summary, node);
  body.insertBefore(details, currentAssistantNodes.text);
  currentAssistantNodes.reasoning = node;
  return node;
}

function updateAssistantReasoning() {
  if (!currentAssistantNodes || !currentAssistantNodes.reasoningText) return;
  const node = ensureReasoningNode();
  if (node) node.textContent = currentAssistantNodes.reasoningText;
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

function settleReasoning() {
  const details = currentAssistantNodes?.text?.closest(".message-body")?.querySelector(".reasoning");
  if (!details) return;
  details.open = false;
  const summary = details.querySelector("summary");
  if (summary) summary.textContent = `Razonamiento · ${details.querySelector(".reasoning-text")?.textContent.length ?? 0} caracteres`;
}

async function readCompletion(response, assistant) {
  const type = response.headers.get("content-type") || "";
  if (!type.includes("text/event-stream")) {
    const data = await response.json();
    const message = data.choices?.[0]?.message ?? {};
    assistant.text = typeof message.content === "string" ? message.content : "";
    assistant.reasoning = typeof message.reasoning_content === "string" ? message.reasoning_content : "";
    assistant.speed = data.timings?.predicted_per_second ?? null;
    updateAssistantText(assistant.text);
    return;
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let completionTokens = null;
  let predictedPerSecond = null;
  let firstTokenAt = null;
  while (true) {
    const part = await reader.read();
    buffer += decoder.decode(part.value ?? new Uint8Array(), { stream: !part.done });
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() ?? "";
    for (const line of lines) {
      if (!line.startsWith("data:")) continue;
      const value = line.slice(5).trim();
      if (!value || value === "[DONE]") continue;
      let chunk;
      try { chunk = JSON.parse(value); } catch { continue; }
      if (chunk.error) throw new Error(chunk.error.message || "Jan devolvió un error");
      if (Number.isFinite(chunk.timings?.predicted_per_second)) predictedPerSecond = chunk.timings.predicted_per_second;
      if (Number.isFinite(chunk.usage?.completion_tokens)) completionTokens = chunk.usage.completion_tokens;
      const delta = chunk.choices?.[0]?.delta ?? {};
      const reasoning = delta.reasoning_content;
      if (typeof reasoning === "string" && reasoning) {
        firstTokenAt ??= performance.now();
        assistant.reasoning = (assistant.reasoning ?? "") + reasoning;
        currentAssistantNodes.reasoningText = assistant.reasoning;
        updateAssistantReasoning();
      }
      const content = delta.content;
      if (typeof content === "string" && content) {
        firstTokenAt ??= performance.now();
        assistant.text += content;
        updateAssistantText(assistant.text);
      }
    }
    if (part.done) break;
  }
  const elapsed = firstTokenAt === null ? 0 : Math.max((performance.now() - firstTokenAt) / 1000, 0.001);
  if (predictedPerSecond !== null) assistant.speed = predictedPerSecond;
  else if (completionTokens !== null && elapsed > 0) assistant.speed = completionTokens / elapsed;
}

async function sendMessage() {
  const chat = getChat();
  if (!chat || activeRequest) return;
  const text = promptEl.value.trim();
  if (!text && !pendingPhoto) return;
  if (pendingPhoto && pendingPhoto.file.size > 20 * 1024 * 1024) {
    showToast("La foto debe pesar menos de 20 MB.");
    return;
  }

  const model = modelSelect.value in MODELS ? modelSelect.value : "spark-4b";
  chat.model = model;
  const userMessage = {
    role: "user",
    text: text || "Analiza esta foto y descríbeme lo importante.",
    hasImage: Boolean(pendingPhoto),
    imageData: pendingPhoto?.dataUrl ?? null,
  };
  if (chat.title === "Nuevo chat") chat.title = (text || "Foto").slice(0, 36);
  chat.messages.push(userMessage);
  chat.updatedAt = Date.now();
  persist();
  promptEl.value = "";
  promptEl.style.height = "auto";
  clearPendingPhoto();

  const assistant = { role: "assistant", text: "", reasoning: "", streaming: true };
  chat.messages.push(assistant);
  render();
  const lastRow = messagesEl.querySelectorAll(".message.assistant");
  const lastBody = lastRow[lastRow.length - 1];
  currentAssistantNodes = {
    text: lastBody?.querySelector(".message-text") ?? null,
    thinking: lastBody?.querySelector(".typing-indicator") ?? null,
    reasoningText: "",
    reasoning: lastBody?.querySelector(".reasoning-text") ?? null,
  };
  sendButton.disabled = true;
  activeRequest = new AbortController();
  setStatus(true, `Jan · ${MODELS[model].label}`);

  const history = chat.messages.filter((message) => !message.streaming).slice(-24).map(apiMessage);
  const settings = MODELS[model];
  try {
    const response = await fetch(`${API}/chat/completions`, {
      method: "POST",
      headers: { Authorization: `Bearer ${API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model,
        messages: [{ role: "system", content: SYSTEM_PROMPT }, ...history],
        temperature: settings.temperature,
        top_p: settings.top_p,
        max_tokens: 4096,
        stream: true,
        stream_options: { include_usage: true },
      }),
      signal: activeRequest.signal,
    });
    if (!response.ok) {
      let detail = {};
      try { detail = await response.json(); } catch {}
      throw new Error(detail.error?.message || `HTTP ${response.status}`);
    }
    await readCompletion(response, assistant);
    if (!assistant.text.trim() && assistant.reasoning?.trim()) {
      // Model exhausted the budget inside the reasoning channel: show what it
      // did produce instead of an empty bubble.
      assistant.text = assistant.reasoning.trim();
      assistant.reasoning = "";
    }
    if (!assistant.text.trim()) assistant.text = "Jan devolvió una respuesta vacía.";
  } catch (error) {
    assistant.error = true;
    assistant.text = error.name === "AbortError"
      ? (assistant.text || "Respuesta detenida.")
      : String(error.message).includes("Jan is not running")
        ? "Jan no tiene un modelo cargado. Abre Jan en el PC, carga TwIL o Qwen y vuelve a intentar."
        : `No pude hablar con Jan: ${error.message || error}`;
  } finally {
    assistant.streaming = false;
    settleReasoning();
    chat.updatedAt = Date.now();
    persist();
    render();
    sendButton.disabled = false;
    activeRequest = null;
    currentAssistantNodes = null;
    await checkJan(false);
  }
}

function createChat() {
  const chat = {
    id: globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`,
    title: "Nuevo chat",
    model: modelSelect.value || "spark-4b",
    updatedAt: Date.now(),
    messages: [],
  };
  chats.unshift(chat);
  activeId = chat.id;
  persist();
  render();
  promptEl.focus();
  closeSidebar();
}

function selectChat(chatId) {
  activeId = chatId;
  const chat = getChat();
  if (chat) modelSelect.value = chat.model in MODELS ? chat.model : "spark-4b";
  render();
  closeSidebar();
}

function initialize() {
  if (!chats.length) {
    chats = [{ id: makeId(), title: "Nuevo chat", model: "spark-4b", updatedAt: Date.now(), messages: [] }];
    activeId = chats[0].id;
  }
  modelSelect.value = getChat()?.model in MODELS ? getChat().model : "spark-4b";
  render();
  checkJan(false);
}

$("#new-chat").addEventListener("click", createChat);
$("#menu-button").addEventListener("click", () => { sidebar.classList.add("open"); backdrop.classList.add("open"); });
backdrop.addEventListener("click", closeSidebar);
$("#retry-models").addEventListener("click", () => checkJan(true));
$("#attach-button").addEventListener("click", () => photoInput.click());
$("#remove-attachment").addEventListener("click", clearPendingPhoto);
photoInput.addEventListener("change", async () => {
  const file = photoInput.files?.[0];
  if (!file) return;
  if (!["image/png", "image/jpeg", "image/gif", "image/webp"].includes(file.type)) { showToast("Adjunta PNG, JPG, GIF o WebP."); return; }
  if (file.size > 20 * 1024 * 1024) { showToast("La foto debe pesar menos de 20 MB."); return; }
  try {
    showToast("Spark no ve imágenes: este modelo es solo texto.");
    photoInput.value = "";
  } catch (error) {
    showToast(error.message || "No pude leer la foto.");
  }
});
modelSelect.addEventListener("change", () => {
  const chat = getChat();
  if (chat) { chat.model = modelSelect.value; persist(); }
});
$("#composer").addEventListener("submit", (event) => { event.preventDefault(); sendMessage(); });
promptEl.addEventListener("input", () => {
  promptEl.style.height = "auto";
  promptEl.style.height = `${Math.min(promptEl.scrollHeight, 180)}px`;
});
promptEl.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.shiftKey) { event.preventDefault(); sendMessage(); }
});
document.querySelectorAll(".suggestions button").forEach((button) => {
  button.addEventListener("click", () => {
    promptEl.value = button.dataset.prompt ?? "";
    promptEl.focus();
    promptEl.dispatchEvent(new Event("input"));
  });
});

initialize();
