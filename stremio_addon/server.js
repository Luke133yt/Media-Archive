#!/usr/bin/env node
/**
 * Media Archive → Stremio / Nuvio addon.
 *
 * Usage:
 *   MEDIA_ARCHIVE_JSON=./backup.json node server.js
 *   MEDIA_ARCHIVE_JSON_URL=https://.../backup.json node server.js
 *   node server.js   # then open /configure and drag-drop a backup
 *
 * Install in Stremio: stremio://HOST:PORT/manifest.json
 * Install in Nuvio: paste http://HOST:PORT/manifest.json in Addons.
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const PORT = Number(process.env.PORT || 7001);
const LOGO =
  'https://raw.githubusercontent.com/Luke133yt/Media-Archive/main/assets/branding/media_archive_logo.png';

/** @type {{items: any[], loadedAt?: string, source?: string}} */
let catalog = { items: [], source: 'empty' };

async function loadFromEnv() {
  if (process.env.MEDIA_ARCHIVE_JSON) {
    const file = path.resolve(process.env.MEDIA_ARCHIVE_JSON);
    const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
    catalog = {
      items: normalizeItems(raw),
      loadedAt: new Date().toISOString(),
      source: file,
    };
    console.log(`Loaded ${catalog.items.length} items from ${file}`);
  } else if (process.env.MEDIA_ARCHIVE_JSON_URL) {
    await loadFromUrl(process.env.MEDIA_ARCHIVE_JSON_URL);
  }
}

async function loadFromUrl(url) {
  const res = await fetch(driveDirect(url));
  if (!res.ok) throw new Error(`Catalog URL HTTP ${res.status}`);
  const raw = await res.json();
  catalog = {
    items: normalizeItems(raw),
    loadedAt: new Date().toISOString(),
    source: url,
  };
  console.log(`Loaded ${catalog.items.length} items from URL`);
}

function driveDirect(url) {
  try {
    const u = new URL(url);
    if (u.hostname.includes('drive.google.com')) {
      const id =
        u.searchParams.get('id') ||
        (u.pathname.match(/\/file\/d\/([^/]+)/) || [])[1];
      if (id) return `https://drive.google.com/uc?export=download&id=${id}`;
    }
  } catch (_) {}
  return url;
}

function normalizeItems(raw) {
  const list = Array.isArray(raw) ? raw : raw.items || [];
  return list
    .map((item) => ({
      id: item.id,
      tmdbId: item.tmdbId ?? item.tmdb_id ?? null,
      type: item.type === 'tv' ? 'tv' : 'movie',
      title: item.title || '',
      originalTitle: item.originalTitle || item.original_title || '',
      year: item.year ?? null,
      format: item.format || 'Non Specificato',
      region: item.region || '',
      mediaLanguage: item.mediaLanguage || item.language || '',
      posterPath: item.posterPath || item.poster_path || null,
      backdropPath: item.backdropPath || item.backdrop_path || null,
      overview: item.overview || '',
      voteAverage: item.voteAverage ?? item.tmdb_rating ?? null,
      genres: item.genres || [],
      watched: !!item.watched,
      archived: !!item.archived,
      lostMedia: !!item.lostMedia,
      addedAt: item.addedAt || item.added_at || null,
      director: item.director || null,
      cast: item.cast || [],
      runtime: item.runtime ?? null,
    }))
    .filter((i) => i.title);
}

function tmdbImg(p, size = 'w500') {
  if (!p) return null;
  if (String(p).startsWith('http')) return p;
  return `https://image.tmdb.org/t/p/${size}${p.startsWith('/') ? p : `/${p}`}`;
}

function formatEmoji(format) {
  const n = String(format).toLowerCase();
  if (/vhs|beta|video 2000|hi8|video8/.test(n)) return '📼';
  if (/4k|uhd/.test(n)) return '🟦';
  if (/blu/.test(n)) return '💿';
  if (/dvd|hd-dvd|laser/.test(n)) return '📀';
  if (/mm|super 8/.test(n)) return '🎞️';
  return '📦';
}

function manifest() {
  return {
    id: 'com.luke133yt.mediaarchive',
    version: '1.13.0',
    name: 'Media Archive',
    description:
      'Collezione di media fisici (DVD, Blu-ray, VHS…). Indica se un titolo è nel tuo archivio e con quale supporto.',
    logo: LOGO,
    background: LOGO,
    resources: [
      'catalog',
      {
        name: 'meta',
        types: ['movie', 'series'],
        idPrefixes: ['tmdb', 'tt', 'mediaarchive'],
      },
      {
        name: 'stream',
        types: ['movie', 'series'],
        idPrefixes: ['tmdb', 'tt', 'mediaarchive'],
      },
    ],
    types: ['movie', 'series'],
    idPrefixes: ['tmdb', 'tt', 'mediaarchive'],
    catalogs: [
      {
        type: 'movie',
        id: 'mediaarchive',
        name: 'Physical · Movies',
        extra: [
          { name: 'search', isRequired: false },
          { name: 'skip', isRequired: false },
        ],
      },
      {
        type: 'series',
        id: 'mediaarchive',
        name: 'Physical · Series',
        extra: [
          { name: 'search', isRequired: false },
          { name: 'skip', isRequired: false },
        ],
      },
      {
        type: 'movie',
        id: 'mediaarchive-top',
        name: 'Physical · Top rated',
        extra: [{ name: 'skip', isRequired: false }],
      },
      {
        type: 'movie',
        id: 'mediaarchive-recent',
        name: 'Physical · Recently added',
        extra: [{ name: 'skip', isRequired: false }],
      },
    ],
    behaviorHints: { configurable: true, configurationRequired: false },
  };
}

function toMeta(item) {
  const type = item.type === 'tv' ? 'series' : 'movie';
  const id = item.tmdbId
    ? `tmdb:${item.tmdbId}`
    : `mediaarchive:${item.id || item.title}`;
  const bits = [
    `${formatEmoji(item.format)} ${item.format}`,
    item.region,
    item.mediaLanguage,
    item.watched ? 'Watched' : null,
  ].filter(Boolean);
  return {
    id,
    type,
    name: item.title,
    poster: tmdbImg(item.posterPath),
    background: tmdbImg(item.backdropPath, 'w780'),
    posterShape: 'poster',
    description: `${bits.join(' · ')}\n\n${item.overview || ''}`.trim(),
    releaseInfo: item.year ? String(item.year) : undefined,
    imdbRating:
      item.voteAverage != null ? Number(item.voteAverage).toFixed(1) : undefined,
    genres: item.genres,
    runtime: item.runtime ? `${item.runtime} min` : undefined,
    director: item.director ? [item.director] : undefined,
    cast: Array.isArray(item.cast)
      ? item.cast.map((c) => (typeof c === 'string' ? c : c.name)).filter(Boolean)
      : undefined,
    links: [
      {
        name: item.format,
        category: 'Physical format',
        url: 'https://github.com/Luke133yt/Media-Archive',
      },
    ],
  };
}

function findAll(rawId) {
  const id = decodeURIComponent(rawId);
  if (id.startsWith('mediaarchive:')) {
    const local = id.slice('mediaarchive:'.length);
    return catalog.items.filter((e) => String(e.id) === local);
  }
  if (id.startsWith('tmdb:')) {
    const tmdb = Number(id.slice(5));
    return catalog.items.filter((e) => Number(e.tmdbId) === tmdb);
  }
  const asInt = Number(id);
  if (!Number.isNaN(asInt) && id !== '') {
    return catalog.items.filter((e) => Number(e.tmdbId) === asInt);
  }
  return [];
}

function catalogResponse(type, catalogId, search) {
  const wantTv = type === 'series';
  let items = catalog.items.filter(
    (e) => (e.type === 'tv') === wantTv && e.tmdbId != null,
  );
  if (search) {
    const q = search.toLowerCase();
    items = items.filter(
      (e) =>
        e.title.toLowerCase().includes(q) ||
        String(e.originalTitle || '')
          .toLowerCase()
          .includes(q),
    );
  }
  if (catalogId === 'mediaarchive-top') {
    items.sort((a, b) => (b.voteAverage || 0) - (a.voteAverage || 0));
  } else if (catalogId === 'mediaarchive-recent') {
    items.sort((a, b) => String(b.addedAt || '').localeCompare(String(a.addedAt || '')));
  } else {
    items.sort((a, b) => a.title.localeCompare(b.title));
  }
  return { metas: items.slice(0, 100).map(toMeta) };
}

function ownershipStream(item) {
  return {
    name: `${formatEmoji(item.format)} ${item.format}`,
    title: `In Media Archive · ${item.format}${item.region ? ` · ${item.region}` : ''}`,
    description: 'Hai questo titolo in formato fisico nel database Media Archive.',
    behaviorHints: { notWebReady: true, bingeGroup: 'mediaarchive-owned' },
    externalUrl: 'https://github.com/Luke133yt/Media-Archive',
  };
}

function configureHtml(reqHost) {
  const manifestUrl = `http://${reqHost}/manifest.json`;
  const stremio = manifestUrl.replace(/^https?:\/\//, 'stremio://');
  return `<!doctype html>
<html lang="it"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Media Archive addon</title>
<style>
body{font-family:system-ui,sans-serif;max-width:760px;margin:40px auto;padding:0 16px;background:#0f1220;color:#eef2ff}
.card{background:#171b33;border-radius:16px;padding:20px;margin:16px 0}
button,.btn{background:#6d86ff;color:#fff;border:0;border-radius:12px;padding:12px 16px;font-weight:700;cursor:pointer;text-decoration:none;display:inline-block}
input,textarea{width:100%;box-sizing:border-box;border-radius:10px;border:1px solid #31406e;background:#0f1220;color:#fff;padding:10px;margin:8px 0}
#drop{border:2px dashed #4a5d9a;border-radius:16px;padding:28px;text-align:center;color:#b8c4ef}
#drop.over{border-color:#9db7ff;background:#1b2140}
code{background:#1b2140;padding:2px 6px;border-radius:6px}
a{color:#9db7ff}
</style></head><body>
<h1>Media Archive → Nuvio / Stremio</h1>
<div class="card">
  <p>Titoli caricati: <strong id="count">${catalog.items.length}</strong>
  ${catalog.source ? ` · fonte <code>${catalog.source}</code>` : ''}</p>
  <p>Manifest: <code id="m">${manifestUrl}</code></p>
  <p>
    <button onclick="navigator.clipboard.writeText(document.getElementById('m').textContent)">Copia URL</button>
    <a class="btn" href="${stremio}">Installa in Stremio</a>
  </p>
  <p>Su <b>Nuvio</b>: Impostazioni → Addons → incolla l’URL del manifest.</p>
</div>
<div class="card">
  <h3>Carica backup Media Archive</h3>
  <div id="drop">Trascina qui il JSON di backup, oppure clicca per scegliere un file</div>
  <input id="file" type="file" accept="application/json,.json" hidden/>
  <h4>Oppure URL (Google Drive / link diretto)</h4>
  <input id="url" placeholder="https://drive.google.com/file/d/.../view oppure link raw"/>
  <button id="loadUrl">Carica da URL</button>
  <pre id="msg"></pre>
</div>
<script>
const drop=document.getElementById('drop');
const file=document.getElementById('file');
const msg=document.getElementById('msg');
drop.onclick=()=>file.click();
drop.ondragover=e=>{e.preventDefault();drop.classList.add('over')};
drop.ondragleave=()=>drop.classList.remove('over');
drop.ondrop=async e=>{e.preventDefault();drop.classList.remove('over');const f=e.dataTransfer.files[0];if(f)await upload(f)};
file.onchange=async()=>{if(file.files[0])await upload(file.files[0])};
async function upload(f){
  msg.textContent='Caricamento…';
  const text=await f.text();
  const res=await fetch('/upload',{method:'POST',headers:{'content-type':'application/json'},body:text});
  const j=await res.json();
  msg.textContent=res.ok?('OK: '+j.count+' titoli'): (j.error||'errore');
  if(res.ok) location.reload();
}
document.getElementById('loadUrl').onclick=async()=>{
  msg.textContent='Scarico…';
  const res=await fetch('/load-url',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({url:document.getElementById('url').value})});
  const j=await res.json();
  msg.textContent=res.ok?('OK: '+j.count+' titoli'): (j.error||'errore');
  if(res.ok) location.reload();
};
</script>
</body></html>`;
}

function send(res, code, body, type = 'application/json') {
  const data = typeof body === 'string' ? body : JSON.stringify(body);
  res.writeHead(code, {
    'content-type': `${type}; charset=utf-8`,
    'access-control-allow-origin': '*',
    'access-control-allow-headers': '*',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
  });
  res.end(data);
}

async function readBody(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  return Buffer.concat(chunks).toString('utf8');
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return send(res, 204, '');
  const host = req.headers.host || `127.0.0.1:${PORT}`;
  const u = new URL(req.url, `http://${host}`);
  try {
    if (u.pathname === '/' || u.pathname === '/configure') {
      return send(res, 200, configureHtml(host), 'text/html');
    }
    if (u.pathname === '/manifest.json') return send(res, 200, manifest());
    if (u.pathname === '/export.json') {
      return send(res, 200, {
        app: 'media_archive',
        version: 1,
        exportedAt: new Date().toISOString(),
        items: catalog.items,
        source: catalog.source,
      });
    }
    if (req.method === 'POST' && u.pathname === '/upload') {
      const raw = JSON.parse(await readBody(req));
      catalog = {
        items: normalizeItems(raw),
        loadedAt: new Date().toISOString(),
        source: 'upload',
      };
      return send(res, 200, { ok: true, count: catalog.items.length });
    }
    if (req.method === 'POST' && u.pathname === '/load-url') {
      const { url } = JSON.parse(await readBody(req));
      await loadFromUrl(url);
      return send(res, 200, { ok: true, count: catalog.items.length });
    }
    const cat = u.pathname.match(/^\/catalog\/(movie|series)\/([^/]+)\.json$/);
    if (cat) {
      return send(
        res,
        200,
        catalogResponse(cat[1], cat[2], u.searchParams.get('search')),
      );
    }
    const meta = u.pathname.match(/^\/meta\/(movie|series)\/([^/]+)\.json$/);
    if (meta) {
      const item = findAll(meta[2])[0];
      return item
        ? send(res, 200, { meta: toMeta(item) })
        : send(res, 404, { meta: null });
    }
    const stream = u.pathname.match(/^\/stream\/(movie|series)\/([^/]+)\.json$/);
    if (stream) {
      const matches = findAll(stream[2]);
      return send(res, 200, {
        streams: matches.map(ownershipStream),
      });
    }
    send(res, 404, { error: 'not found' });
  } catch (e) {
    send(res, 500, { error: String(e && e.message ? e.message : e) });
  }
});

loadFromEnv()
  .then(() => {
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`Media Archive addon on http://127.0.0.1:${PORT}/manifest.json`);
      console.log(`Configure / upload: http://127.0.0.1:${PORT}/configure`);
    });
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
