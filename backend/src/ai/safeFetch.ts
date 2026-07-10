import { lookup } from "node:dns/promises";
import { isIP } from "node:net";

/// SSRF-hardened fetch for the recipe importer: the only place the server
/// ever requests a user-supplied URL. Defenses:
///  - https only (no http, no other schemes)
///  - DNS-resolves the host and rejects private/loopback/link-local/
///    metadata ranges BEFORE connecting
///  - redirects disabled (a public host can't bounce us to 169.254.x.x)
///  - 8s timeout, 512KB response cap, text only
const MAX_BYTES = 512 * 1024;
const TIMEOUT_MS = 8_000;

export class UnsafeURLError extends Error {}

function isPrivateIPv4(ip: string): boolean {
  const parts = ip.split(".").map(Number);
  if (parts.length !== 4) return true;
  const a = parts[0] ?? 0;
  const b = parts[1] ?? 0;
  return (
    a === 0 || a === 10 || a === 127 ||
    (a === 100 && b >= 64 && b <= 127) || // CGNAT
    (a === 169 && b === 254) ||            // link-local / cloud metadata
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 168)
  );
}

function isPrivateIPv6(ip: string): boolean {
  const lower = ip.toLowerCase();
  return (
    lower === "::1" || lower === "::" ||
    lower.startsWith("fe80") || // link-local
    lower.startsWith("fc") || lower.startsWith("fd") || // unique-local
    lower.startsWith("::ffff:") // v4-mapped — re-check the v4 part
  );
}

async function assertPublicHost(hostname: string): Promise<void> {
  if (isIP(hostname)) {
    const unsafe = isIP(hostname) === 4 ? isPrivateIPv4(hostname) : isPrivateIPv6(hostname);
    if (unsafe) throw new UnsafeURLError("IP address not allowed");
    return;
  }
  let addresses;
  try {
    addresses = await lookup(hostname, { all: true });
  } catch {
    throw new UnsafeURLError("Host did not resolve");
  }
  for (const { address, family } of addresses) {
    if (family === 4 && isPrivateIPv4(address)) throw new UnsafeURLError("Resolves to private address");
    if (family === 6 && isPrivateIPv6(address)) throw new UnsafeURLError("Resolves to private address");
  }
}

export async function safeFetchText(rawURL: string): Promise<string> {
  let url: URL;
  try {
    url = new URL(rawURL);
  } catch {
    throw new UnsafeURLError("Invalid URL");
  }
  if (url.protocol !== "https:") throw new UnsafeURLError("Only https URLs are allowed");
  await assertPublicHost(url.hostname);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      redirect: "manual", // never follow — redirect targets are unvetted
      signal: controller.signal,
      headers: { "user-agent": "FitTrackRecipeBot/1.0 (+recipe import)" },
    });
    if (response.status >= 300 && response.status < 400) {
      throw new UnsafeURLError("Redirects are not followed");
    }
    if (!response.ok) {
      throw new UnsafeURLError(`Upstream returned ${response.status}`);
    }
    const reader = response.body?.getReader();
    if (!reader) return "";
    const chunks: Uint8Array[] = [];
    let received = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      received += value.byteLength;
      if (received > MAX_BYTES) {
        await reader.cancel();
        break;
      }
      chunks.push(value);
    }
    return Buffer.concat(chunks).toString("utf-8");
  } finally {
    clearTimeout(timer);
  }
}

/// Strips tags/scripts so the model sees readable page text, and caps the
/// length so a huge page can't blow up the prompt.
export function htmlToText(html: string, maxChars = 12_000): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#\d+;/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxChars);
}
