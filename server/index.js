#!/usr/bin/env node
/**
 * Archives every PDF uploaded (before edit) and every exported PDF (after edit).
 *
 * Env:
 *   PORT           default 3847
 *   DATA_DIR       default ../data (relative to this file)
 *   API_KEY        optional ù if set, clients must send header X-API-Key: <value>
 *
 * Deploy (VPS): nginx proxy /api -> http://127.0.0.1:3847
 *   pm2 start server/index.js --name pdf-archive
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const Database = require('better-sqlite3');
const PORT = parseInt(process.env.PORT || '3847', 10);
const DATA_DIR = path.resolve(__dirname, process.env.DATA_DIR || path.join(__dirname, '..', 'data'));
const UPLOADS_ROOT = path.join(DATA_DIR, 'uploads');
const EDITS_ROOT = path.join(DATA_DIR, 'upload_edits');
const DB_PATH = path.join(DATA_DIR, 'pdf_archive.sqlite');

fs.mkdirSync(UPLOADS_ROOT, { recursive: true });
fs.mkdirSync(EDITS_ROOT, { recursive: true });

/** UTC date folder YYYY-MM-DD (stable for sorting and backups). */
function dateFolderUtc(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function relPosix(...parts) {
  return path.posix.join(...parts);
}

const db = new Database(DB_PATH);
db.exec(`
  CREATE TABLE IF NOT EXISTS pdf_uploads (
    id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL,
    original_filename TEXT,
    original_size INTEGER NOT NULL DEFAULT 0,
    original_sha256 TEXT,
    original_path TEXT NOT NULL,
    edited_at TEXT,
    edited_size INTEGER,
    edited_sha256 TEXT,
    edited_path TEXT,
    client_ip TEXT
  );
`);

const insertStmt = db.prepare(`
  INSERT INTO pdf_uploads (id, created_at, original_filename, original_size, original_sha256, original_path, client_ip)
  VALUES (@id, @created_at, @original_filename, @original_size, @original_sha256, @original_path, @client_ip)
`);

const updateEditedStmt = db.prepare(`
  UPDATE pdf_uploads SET edited_at = @edited_at, edited_size = @edited_size, edited_sha256 = @edited_sha256, edited_path = @edited_path WHERE id = @id
`);

function sha256Buf(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

function clientIp(req) {
  const xf = req.headers['x-forwarded-for'];
  if (typeof xf === 'string' && xf.length) return xf.split(',')[0].trim();
  return req.socket.remoteAddress || '';
}

function requireApiKey(req, res, next) {
  const key = process.env.API_KEY;
  if (!key) return next();
  if (req.headers['x-api-key'] === key) return next();
  return res.status(401).json({ error: 'Unauthorized' });
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 80 * 1024 * 1024 }
});

const app = express();
app.use(cors({ origin: true }));

app.get('/api/health', (req, res) => {
  res.json({
    ok: true,
    service: 'pdf-archive',
    db: DB_PATH,
    uploads_dir: UPLOADS_ROOT,
    upload_edits_dir: EDITS_ROOT
  });
});

/** Multipart: field "file" + optional "originalName" */
app.post('/api/archive/before', requireApiKey, upload.single('file'), (req, res) => {
  try {
    const buf = req.file && req.file.buffer;
    if (!buf || buf.length < 4 || buf.slice(0, 4).toString('ascii') !== '%PDF') {
      return res.status(400).json({ error: 'Invalid or missing PDF file' });
    }
    const id = crypto.randomUUID();
    const filename = (req.body && req.body.originalName) || (req.file && req.file.originalname) || 'upload.pdf';
    let safeName = String(filename).replace(/[^\w.\- ]+/g, '_').slice(0, 200);
    if (!/\.pdf$/i.test(safeName)) safeName += '.pdf';
    const day = dateFolderUtc();
    const uploadDayDir = path.join(UPLOADS_ROOT, day);
    fs.mkdirSync(uploadDayDir, { recursive: true });
    const pdfFileName = `${id}_${safeName}`;
    const relPath = relPosix('uploads', day, pdfFileName);
    const absPath = path.join(uploadDayDir, pdfFileName);

    fs.writeFileSync(absPath, buf);

    const createdAt = new Date().toISOString();
    const metaPath = path.join(uploadDayDir, `${id}.meta.json`);
    const meta = {
      id,
      type: 'original_upload',
      created_at: createdAt,
      date_folder: day,
      original_filename: safeName,
      bytes: buf.length,
      sha256: sha256Buf(buf),
      stored_pdf: relPath,
      client_ip: clientIp(req)
    };
    fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2), 'utf8');

    const row = {
      id,
      created_at: createdAt,
      original_filename: safeName,
      original_size: buf.length,
      original_sha256: sha256Buf(buf),
      original_path: relPath,
      client_ip: clientIp(req)
    };
    insertStmt.run(row);

    res.status(201).json({ id, original_size: buf.length });
  } catch (e) {
    console.error('archive/before', e);
    res.status(500).json({ error: String(e.message || e) });
  }
});

/** Raw body: application/pdf bytes */
app.post(
  '/api/archive/after/:id',
  requireApiKey,
  express.raw({ type: 'application/pdf', limit: '80mb' }),
  (req, res) => {
  try {
    const id = req.params.id;
    const existing = db.prepare('SELECT id FROM pdf_uploads WHERE id = ?').get(id);
    if (!existing) return res.status(404).json({ error: 'Upload session not found' });

    const buf = Buffer.isBuffer(req.body) ? req.body : Buffer.from(req.body || []);
    if (!buf.length || buf.slice(0, 4).toString('ascii') !== '%PDF') {
      return res.status(400).json({ error: 'Invalid PDF body' });
    }

    const day = dateFolderUtc();
    const editDayDir = path.join(EDITS_ROOT, day);
    fs.mkdirSync(editDayDir, { recursive: true });
    const pdfFileName = `${id}_edited.pdf`;
    const relPath = relPosix('upload_edits', day, pdfFileName);
    const absPath = path.join(editDayDir, pdfFileName);
    fs.writeFileSync(absPath, buf);

    const editedAt = new Date().toISOString();
    const editMetaPath = path.join(editDayDir, `${id}_edited.meta.json`);
    const editMeta = {
      id,
      type: 'edited_export',
      edited_at: editedAt,
      date_folder: day,
      bytes: buf.length,
      sha256: sha256Buf(buf),
      stored_pdf: relPath
    };
    fs.writeFileSync(editMetaPath, JSON.stringify(editMeta, null, 2), 'utf8');

    updateEditedStmt.run({
      id,
      edited_at: editedAt,
      edited_size: buf.length,
      edited_sha256: sha256Buf(buf),
      edited_path: relPath
    });

    res.status(201).json({ id, edited_size: buf.length });
  } catch (e) {
    console.error('archive/after', e);
    res.status(500).json({ error: String(e.message || e) });
  }
}
);

app.listen(PORT, '127.0.0.1', () => {
  console.log(`PDF archive API listening on http://127.0.0.1:${PORT}`);
  console.log(`Database:      ${DB_PATH}`);
  console.log(`Uploads:       ${UPLOADS_ROOT}/<YYYY-MM-DD>/`);
  console.log(`After export:  ${EDITS_ROOT}/<YYYY-MM-DD>/`);
});
