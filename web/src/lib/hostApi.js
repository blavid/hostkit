import { TV_SERVICE_NOT_LIVE, normalizeApiBase, isApiConfigured } from "./apiConfig.js";

export { TV_SERVICE_NOT_LIVE, isApiConfigured };

function notLive() {
  const err = new Error(TV_SERVICE_NOT_LIVE);
  err.code = "not_live";
  return err;
}

export function createHostApi({ apiBase, getToken, fetchImpl = fetch } = {}) {
  const base = normalizeApiBase(apiBase);

  async function request(method, path, { body, token } = {}) {
    if (!base) throw notLive();
    const headers = { accept: "application/json" };
    const auth = token ?? (typeof getToken === "function" ? getToken() : "");
    if (auth) headers.Authorization = `Bearer ${auth}`;
    const init = { method, headers };
    if (body !== undefined) {
      headers["content-type"] = "application/json";
      init.body = JSON.stringify(body);
    }
    let res;
    try {
      res = await fetchImpl(`${base}${path}`, init);
    } catch {
      throw notLive();
    }
    const text = await res.text();
    let json = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = null;
    }
    if (!res.ok) {
      const err = new Error((json && (json.error || json.message)) || `HTTP ${res.status}`);
      err.status = res.status;
      err.body = json;
      throw err;
    }
    return json;
  }

  return {
    get live() {
      return Boolean(base);
    },
    async signup() {
      return request("POST", "/v1/host/signup", { body: {} });
    },
    async claim(code, propertyId) {
      return request("POST", "/v1/pair/claim", { body: { code, propertyId } });
    },
    async revoke({ deviceId, deviceToken } = {}) {
      return request("POST", "/v1/pair/revoke", { body: { deviceId, deviceToken } });
    },
    async listDevices() {
      return request("GET", "/v1/host/devices");
    },
    async putPrivate(propertyId, values) {
      return request("PUT", "/v1/host/private", { body: { propertyId, values } });
    },
    async putConfig(doc) {
      return request("PUT", "/v1/config", { body: doc });
    },
  };
}

const STORAGE_KEY = "hostkit.preview.session";

export function loadStoredSession(storage = globalThis.localStorage) {
  try {
    const raw = storage?.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed || !parsed.token || !parsed.hostId) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function storeSession(session, storage = globalThis.localStorage) {
  if (!storage) return;
  storage.setItem(
    STORAGE_KEY,
    JSON.stringify({
      token: session.token,
      hostId: session.hostId,
      propertyId: session.propertyId,
      expiresAt: session.expiresAt,
    })
  );
}

export function clearSession(storage = globalThis.localStorage) {
  try {
    storage?.removeItem(STORAGE_KEY);
  } catch {
    // ignore
  }
}
