const API = "/jan-api/v1";
const API_KEY = "jan-local";
const STORAGE_KEY = "jan-remoto-chat-v1";
const MODELS = {
  "twil-8b": { label: "TwIL 8B · Razonamiento", temperature: 1, top_p: 0.95 },
  "qwen3-vl-4b": { label: "Qwen3 VL · Fotos", temperature: 0.7, top_p: 0.8 },
};
const SYSTEM_PROMPT = "Eres Jan, un asistente local. Responde en el idioma del usuario, de forma clara y natural. Esta pantalla es solo para conversar: no afirmes haber ejecutado comandos ni editado archivos. Si recibes una imagen, analízala con atención.";
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
let currentAssistantNode = null;

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
      modelSelect.value = chat.model in MODELS ? chat.model : "twil-8b";
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

  const text = document.createElement("div");
  text.className = "message-text";
  text.textContent = message.text || "";
  text.dataset.messageIndex = String(index);
  body.append(text);
  if (message.streaming && !message.text) {
    const thinking = document.createElement("div");
    thinking.className = "typing-indicator";
    thinking.innerHTML = "<i></i><i></i><i></i><span>Jan está pensando</span>";
    body.append(thinking);
  }
  if (message.speed) {
    const speed = document.createElement("div");
    speed.className = "message-speed";
    speed.textContent = `${message.speed.toFixed(1)} tokens/s`;
    body.append(speed);
  }
  row.append(avatar, body);
  return row;
}

function render() {
  renderHistory();
  const chat = getChat();
  if (!chat) return;
  modelSelect.value = chat.model in MODELS ? chat.model : "twil-8b";
  welcomeEl.hidden = chat.messages.length > 0;
  messagesEl.replaceChildren();
  const list = document.createElement("div");
  list.className = "message-list";
  chat.messages.forEach((message, index) => list.append(renderMessage(message, index)));
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
    if (!available.has("twil-8b") || !available.has("qwen3-vl-4b")) throw new Error("Faltan modelos");
    setStatus(true, "Jan local listo");
    return true;
  } catch {
    setStatus(false, "Jan desconectado");
    if (showMessage) showToast("Abre Jan en la PC, carga TwIL o Qwen y vuelve a intentar.");
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
  if (currentAssistantNode) {
    currentAssistantNode.textContent = text;
    currentAssistantNode.closest(".message-body")?.querySelector(".typing-indicator")?.remove();
    messagesEl.scrollTop = messagesEl.scrollHeight;
  }
}

async function readCompletion(response, assistant) {
  const type = response.headers.get("content-type") || "";
  if (!type.includes("text/event-stream")) {
    const data = await response.json();
    assistant.text = data.choices?.[0]?.message?.content ?? "";
    assistant.speed = data.timings?.predicted_per_second ?? null;
    updateAssistantText(assistant.text);
    return;
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let completionTokens = null;
  let predictedPerSecond = null;
  let firstContentAt = null;
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
      const content = chunk.choices?.[0]?.delta?.content;
      if (typeof content === "string") {
        firstContentAt ??= performance.now();
        assistant.text += content;
        updateAssistantText(assistant.text);
      }
    }
    if (part.done) break;
  }
  const elapsed = firstContentAt === null ? 0 : Math.max((performance.now() - firstContentAt) / 1000, 0.001);
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

  const model = modelSelect.value in MODELS ? modelSelect.value : "twil-8b";
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

  const assistant = { role: "assistant", text: "", streaming: true };
  chat.messages.push(assistant);
  render();
  const responseNodes = messagesEl.querySelectorAll(".message.assistant .message-text");
  currentAssistantNode = responseNodes[responseNodes.length - 1] ?? null;
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
        max_tokens: 2048,
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
    chat.updatedAt = Date.now();
    persist();
    render();
    sendButton.disabled = false;
    activeRequest = null;
    currentAssistantNode = null;
    await checkJan(false);
  }
}

function createChat() {
  const chat = {
    id: globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`,
    title: "Nuevo chat",
    model: modelSelect.value || "twil-8b",
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
  if (chat) modelSelect.value = chat.model in MODELS ? chat.model : "twil-8b";
  render();
  closeSidebar();
}

function initialize() {
  if (!chats.length) {
    chats = [{ id: makeId(), title: "Nuevo chat", model: "twil-8b", updatedAt: Date.now(), messages: [] }];
    activeId = chats[0].id;
  }
  modelSelect.value = getChat()?.model in MODELS ? getChat().model : "twil-8b";
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
    const dataUrl = await readDataUrl(file);
    pendingPhoto = { file, dataUrl };
    attachmentImage.src = dataUrl;
    attachmentName.textContent = file.name || "Foto";
    attachmentBox.hidden = false;
    modelSelect.value = "qwen3-vl-4b";
    const chat = getChat();
    if (chat) chat.model = modelSelect.value;
    persist();
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
