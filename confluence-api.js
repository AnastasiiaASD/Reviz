// confluence-api.js
function getConfluenceConfig() {
  const raw = process.env.JIRA_JSON;
  if (!raw) throw new Error("JIRA_JSON env var not set");
  const cfg = JSON.parse(raw);
  return {
    host:  cfg.host.replace(/\/$/, ""),
    email: cfg.email,
    token: cfg.token,
    auth:  Buffer.from(`${cfg.email}:${cfg.token}`).toString("base64"),
  };
}

async function confluenceRequest(method, path, body = null) {
  const cfg = getConfluenceConfig();
  const url = `${cfg.host}/wiki/rest/api${path}`;

  const opts = {
    method,
    headers: {
      "Authorization": `Basic ${cfg.auth}`,
      "Content-Type":  "application/json",
      "Accept":        "application/json",
    },
  };

  if (body) opts.body = JSON.stringify(body);

  const res = await fetch(url, opts);
  const text = await res.text();

  if (!res.ok) {
    throw new Error(`Confluence API ${res.status} ${method} ${path}: ${text}`);
  }

  return text ? JSON.parse(text) : null;
}

async function createPage(spaceKey, title, content, parentId = null) {
  const body = {
    type:  "page",
    title,
    space: { key: spaceKey },
    body:  {
      storage: {
        value:          content,
        representation: "storage",
      },
    },
  };

  if (parentId) {
    body.ancestors = [{ id: parentId }];
  }

  return confluenceRequest("POST", "/content", body);
}

async function findPage(spaceKey, title) {
  const encoded = encodeURIComponent(title);
  const data = await confluenceRequest(
    "GET",
    `/content?spaceKey=${spaceKey}&title=${encoded}&expand=version`
  );
  return data.results?.[0] || null;
}

async function updatePage(pageId, title, content, currentVersion) {
  return confluenceRequest("PUT", `/content/${pageId}`, {
    type:    "page",
    title,
    version: { number: currentVersion + 1 },
    body:    {
      storage: {
        value:          content,
        representation: "storage",
      },
    },
  });
}

// Upsert: створити якщо немає, оновити якщо є
async function upsertPage(spaceKey, title, content, parentId = null) {
  const existing = await findPage(spaceKey, title);

  if (existing) {
    const version = existing.version.number;
    const updated = await updatePage(existing.id, title, content, version);
    const cfg = getConfluenceConfig();
    return { url: `${cfg.host}/wiki${updated._links.webui}`, created: false };
  }

  const created = await createPage(spaceKey, title, content, parentId);
  const cfg = getConfluenceConfig();
  return { url: `${cfg.host}/wiki${created._links.webui}`, created: true };
}

module.exports = { createPage, findPage, updatePage, upsertPage };

// CLI: node /app/confluence-api.js upsert <spaceKey> <title> <contentFile> [parentId]
async function main() {
  const [,, command, spaceKey, title, contentFile, parentId] = process.argv;

  if (command !== "upsert") {
    console.error("Usage: node confluence-api.js upsert <spaceKey> <title> <contentFile> [parentId]");
    process.exit(1);
  }

  const fs = require("fs");
  const content = fs.readFileSync(contentFile, "utf8");

  try {
    const result = await upsertPage(spaceKey, title, content, parentId || null);
    const action = result.created ? "✅ Created" : "🔄 Updated";
    console.log(`${action}: ${result.url}`);
  } catch (err) {
    console.error("❌ Confluence error:", err.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
