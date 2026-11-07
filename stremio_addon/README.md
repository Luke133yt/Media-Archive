# Media Archive · Stremio / Nuvio addon

Addon compatibile Stremio (e quindi Nuvio) che espone la tua collezione di media **fisici**.

## Cosa fa

- Cataloghi `Physical · Movies / Series / Top rated / Recently added`
- Su ogni titolo: descrizione con **formato** (DVD, Blu-ray, VHS…)
- Risorsa `stream`: se il film/serie è nel database, mostra una voce “In Media Archive · Blu-ray” (non è uno stream digitale)

## Avvio rapido

```sh
cd stremio_addon
# Opzione A: file di backup esportato da Media Archive
MEDIA_ARCHIVE_JSON=../backup.json node server.js

# Opzione B: link diretto (anche Google Drive)
MEDIA_ARCHIVE_JSON_URL='https://drive.google.com/uc?export=download&id=FILE_ID' node server.js

# Opzione C: apri /configure e trascina il JSON
node server.js
```

Apri `http://127.0.0.1:7001/configure`.

- **Stremio**: usa il pulsante *Installa in Stremio* oppure `stremio://127.0.0.1:7001/manifest.json`
- **Nuvio**: Impostazioni → Addons → incolla `http://HOST:7001/manifest.json`

> Nuvio su Android richiede spesso **HTTPS**. In LAN usa l’IP del PC; per uso remoto metti l’addon dietro un tunnel HTTPS (Cloudflare Tunnel, Caddy, ecc.) oppure hosta il JSON su Drive e tieni l’addon su un VPS.

## Da Media Archive

In **Impostazioni → Nuvio / Stremio**:

1. **Backup JSON** / **Upload to Nuvio** esporta il database
2. Avvia il server addon locale dall’app (desktop) e copia il manifest
3. Oppure carica il backup su Google Drive e avvialo qui con `MEDIA_ARCHIVE_JSON_URL`
