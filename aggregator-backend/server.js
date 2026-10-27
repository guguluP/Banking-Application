// Sandbox Account Aggregator stand-in.
// It does not speak to Setu, Finvu, or a real AA. It keeps a consent, returns
// one normalized batch, then deletes that batch.
const http = require("http");

const consents = new Map();
const MAX_BODY_BYTES = 1024 * 1024; // 1 MB

function send(res, code, body) {
  const data = JSON.stringify(body);
  res.writeHead(code, { "Content-Type": "application/json" });
  res.end(data);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://127.0.0.1");
  if (req.method === "POST" && url.pathname === "/v1/consent") {
    let raw = "";
    let tooLarge = false;
    req.on("data", (chunk) => {
      if (tooLarge) return;
      raw += chunk;
      if (Buffer.byteLength(raw) > MAX_BODY_BYTES) {
        tooLarge = true;
        raw = "";
        send(res, 413, { error: "request body too large" });
        req.resume();
      }
    });
    req.on("end", () => {
      if (tooLarge) return;
      let body;
      try {
        body = JSON.parse(raw || "{}");
      } catch {
        send(res, 400, { error: "invalid JSON" });
        return;
      }
      if (body === null || typeof body !== "object") {
        send(res, 400, { error: "expected a JSON object" });
        return;
      }
      const consentId = Math.random().toString(36).slice(2, 10);
      consents.set(consentId, {
        mobile: body.mobile || "",
        events: [
          { amount: "250.00", direction: "debit", accountLast4: "0400", merchant: "Demo Store", externalRef: "UTR" + consentId, bank: "Sandbox" }
        ]
      });
      send(res, 200, { consentId });
    });
    return;
  }
  const fi = url.pathname.match(/^\/v1\/fi\/([^/]+)$/);
  if (req.method === "GET" && fi) {
    const batch = consents.get(fi[1]);
    if (!batch) {
      send(res, 404, { error: "unknown or already fetched" });
      return;
    }
    consents.delete(fi[1]);
    send(res, 200, batch.events);
    return;
  }
  send(res, 404, { error: "not found" });
});

server.listen(8787, "127.0.0.1", () => {
  console.log("AA sandbox on http://127.0.0.1:8787");
});
