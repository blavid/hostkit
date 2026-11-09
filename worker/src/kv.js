/**
 * In-memory KV that matches the small subset of Cloudflare KV used here:
 * get, put (with expirationTtl / expiration), delete.
 * Production binds env.KV to a real namespace; tests and the local server
 * use MemoryKV.
 */
export class MemoryKV {
  constructor(clock = () => Date.now()) {
    this.map = new Map();
    this.clock = clock;
  }

  async get(key, type = "text") {
    const row = this.map.get(key);
    if (!row) return null;
    if (row.expiresAt != null && this.clock() >= row.expiresAt) {
      this.map.delete(key);
      return null;
    }
    if (type === "json") {
      try {
        return JSON.parse(row.value);
      } catch {
        return null;
      }
    }
    return row.value;
  }

  async put(key, value, options = {}) {
    const text = typeof value === "string" ? value : JSON.stringify(value);
    let expiresAt = null;
    if (options.expiration != null) {
      expiresAt = Number(options.expiration) * 1000;
    } else if (options.expirationTtl != null) {
      expiresAt = this.clock() + Number(options.expirationTtl) * 1000;
    }
    this.map.set(key, { value: text, expiresAt });
  }

  async delete(key) {
    this.map.delete(key);
  }

  async list({ prefix = "" } = {}) {
    const keys = [];
    for (const [name, row] of this.map) {
      if (row.expiresAt != null && this.clock() >= row.expiresAt) {
        this.map.delete(name);
        continue;
      }
      if (name.startsWith(prefix)) keys.push({ name });
    }
    return { keys, list_complete: true };
  }
}
