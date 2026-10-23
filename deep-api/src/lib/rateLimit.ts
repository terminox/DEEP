// A tiny in-memory per-key cooldown: at most one hit per `windowMs` per key.
// In memory is enough while Cloud Run runs a single instance (see infra/config.ts);
// a second instance would need this in shared storage.
import { ApiError } from "./errors.js";

export class Cooldown {
  private last = new Map<string, number>();

  constructor(private readonly windowMs: number) {}

  /** Record a hit for `key`, or throw 429 if the previous one is too recent. */
  hit(key: string, nowMs: number = Date.now()): void {
    const prev = this.last.get(key);
    if (prev !== undefined && nowMs - prev < this.windowMs) {
      const wait = Math.ceil((this.windowMs - (nowMs - prev)) / 1000);
      throw new ApiError(429, "rate_limited", `Try again in ${wait}s`);
    }
    this.last.set(key, nowMs);
    // Opportunistic sweep so the map cannot grow without bound.
    if (this.last.size > 10_000) {
      for (const [k, t] of this.last) if (nowMs - t >= this.windowMs) this.last.delete(k);
    }
  }

  /** Forget a key (tests / verify scripts). */
  reset(key?: string): void {
    if (key === undefined) this.last.clear();
    else this.last.delete(key);
  }
}
