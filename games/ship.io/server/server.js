const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer, WebSocket } = require('ws');
const auth = require('./auth');

const PORT = process.env.PORT || 3001;
const MAX_PLAYERS_PER_ROOM = 20;
const WORLD_SIZE = 2600;
const TICK_RATE = 30;
const SNAPSHOT_EVERY_TICKS = 2;
const rooms = new Map();
const PROJECT_ROOT = path.resolve(__dirname, '../../..');
let roomSequence = 1;
let entitySequence = 1;

const server = http.createServer(async (request, response) => {
	const pathname = new URL(request.url, `http://${request.headers.host || 'localhost'}`).pathname;
  if (pathname === '/health') {
    response.writeHead(200, { 'content-type': 'application/json' });
    return response.end(JSON.stringify({ ok: true, rooms: rooms.size }));
  }
  if (pathname.startsWith('/api/')) {
    return handleApi(request, response, pathname);
  }

  const requestedFile = pathname === '/' ? '/web/index.html' : pathname;
  if (!requestedFile.startsWith('/web/') && !requestedFile.startsWith('/games/')) {
    response.writeHead(404).end();
    return;
  }

  const filePath = path.resolve(PROJECT_ROOT, `.${requestedFile}`);
  if (!filePath.startsWith(`${PROJECT_ROOT}${path.sep}`)) {
    response.writeHead(403).end();
    return;
  }

  fs.stat(filePath, (error, stats) => {
    if (error || !stats.isFile()) {
      response.writeHead(404).end();
      return;
    }
    const contentTypes = {
      '.css': 'text/css; charset=utf-8',
      '.html': 'text/html; charset=utf-8',
      '.js': 'text/javascript; charset=utf-8',
      '.json': 'application/json; charset=utf-8',
      '.png': 'image/png',
      '.svg': 'image/svg+xml',
      '.wasm': 'application/wasm',
      '.pck': 'application/octet-stream',
    };
    response.writeHead(200, { 'content-type': contentTypes[path.extname(filePath)] || 'application/octet-stream', 'cache-control': 'no-store' });
    fs.createReadStream(filePath).pipe(response);
  });
});
const websocketServer = new WebSocketServer({ server });

function sendJson(response, status, payload, headers = {}) {
  response.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...headers });
  response.end(JSON.stringify(payload));
}

async function readJson(request) {
  let bytes = 0;
  const chunks = [];
  for await (const chunk of request) {
    bytes += chunk.length;
    if (bytes > 16_384) throw new Error('Richiesta troppo grande.');
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw new Error('Dati non validi.');
  }
}

async function handleApi(request, response, pathname) {
  try {
    const token = auth.readCookie(request.headers.cookie, 'cg_session');
    if (request.method === 'GET' && pathname === '/api/auth/me') {
      return sendJson(response, 200, { account: await auth.accountFromSession(token) });
    }
    if (request.method === 'POST' && pathname === '/api/auth/register') {
      const body = await readJson(request);
      const account = await auth.register(body.username, body.password);
      const session = auth.createSession(account.id);
      return sendJson(response, 201, { account }, { 'set-cookie': auth.sessionCookie(session) });
    }
    if (request.method === 'POST' && pathname === '/api/auth/login') {
      const body = await readJson(request);
      const account = await auth.login(body.username, body.password);
      if (!account) return sendJson(response, 401, { error: 'Credenziali non valide.' });
      const session = auth.createSession(account.id);
      return sendJson(response, 200, { account }, { 'set-cookie': auth.sessionCookie(session) });
    }
    if (request.method === 'POST' && pathname === '/api/auth/logout') {
      auth.removeSession(token);
      return sendJson(response, 200, { ok: true }, { 'set-cookie': auth.expiredSessionCookie() });
    }
    return sendJson(response, 404, { error: 'Endpoint non trovato.' });
  } catch (error) {
    const isClientError = /nome utente|password|uso|troppo grande|Dati non validi/i.test(error.message);
    return sendJson(response, isClientError ? 400 : 500, { error: isClientError ? error.message : 'Errore del server.' });
  }
}

function random(min, max) { return Math.random() * (max - min) + min; }
function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }
function id(prefix) { entitySequence += 1; return `${prefix}-${entitySequence.toString(36)}`; }
function safeNickname(value) { return String(value || 'Pilota').trim().replace(/[<>]/g, '').slice(0, 16) || 'Pilota'; }
function skin(value) { return ['violet', 'cyan', 'amber'].includes(value) ? value : 'violet'; }

function createRoom() {
  const room = { id: `arena-${roomSequence++}`, players: new Map(), bullets: [], energy: [], lastSpawn: 0 };
  for (let index = 0; index < 80; index += 1) room.energy.push(createEnergy());
  rooms.set(room.id, room);
  return room;
}
function findRoom() { return [...rooms.values()].find((room) => room.players.size < MAX_PLAYERS_PER_ROOM) || createRoom(); }
function createEnergy() { return { id: id('orb'), x: random(65, WORLD_SIZE - 65), y: random(65, WORLD_SIZE - 65) }; }
function createPlayer(socket, payload) {
  return { id: id('pilot'), socket, nickname: safeNickname(payload.nickname), skin: skin(payload.skin), x: random(150, WORLD_SIZE - 150), y: random(150, WORLD_SIZE - 150), angle: 0, health: 100, maxHealth: 100, xp: 0, xpNext: 100, level: 1, score: 0, speed: 185, fireDelay: 380, lastShot: 0, input: { keys: [], angle: 0, shooting: false }, respawnAt: 0 };
}
function broadcast(room, message) { const data = JSON.stringify(message); room.players.forEach((player) => { if (player.socket.readyState === WebSocket.OPEN) player.socket.send(data); }); }
function leaveRoom(player) { const room = player.room; if (!room) return; room.players.delete(player.id); if (room.players.size === 0) rooms.delete(room.id); }

websocketServer.on('connection', (socket) => {
  let player;
  socket.on('message', (raw) => {
    let message;
    try { message = JSON.parse(raw.toString()); } catch { return; }
    if (message.type === 'join' && !player) {
      const room = findRoom();
      player = createPlayer(socket, message); player.room = room; room.players.set(player.id, player);
      socket.send(JSON.stringify({ type: 'joined', id: player.id, roomId: room.id, world: WORLD_SIZE }));
      broadcast(room, { type: 'notice', message: `${player.nickname} è entrato nell’arena.` });
    }
    if (message.type === 'input' && player && Array.isArray(message.keys)) {
      player.input = { keys: message.keys.slice(0, 8), angle: Number.isFinite(message.angle) ? message.angle : player.angle, shooting: Boolean(message.shooting) };
    }
  });
  socket.on('close', () => leaveRoom(player));
});

function tickRoom(room, now, delta) {
  room.players.forEach((player) => {
    if (player.respawnAt) { if (now >= player.respawnAt) respawn(player); else return; }
    const keys = new Set(player.input.keys); let horizontal = 0; let vertical = 0;
    if (keys.has('w') || keys.has('ArrowUp')) vertical -= 1;
    if (keys.has('s') || keys.has('ArrowDown')) vertical += 1;
    if (keys.has('a') || keys.has('ArrowLeft')) horizontal -= 1;
    if (keys.has('d') || keys.has('ArrowRight')) horizontal += 1;
    const magnitude = Math.hypot(horizontal, vertical) || 1;
    player.x = clamp(player.x + horizontal / magnitude * player.speed * delta, 25, WORLD_SIZE - 25);
    player.y = clamp(player.y + vertical / magnitude * player.speed * delta, 25, WORLD_SIZE - 25);
    player.angle = player.input.angle;
    if (player.input.shooting && now - player.lastShot >= player.fireDelay) shoot(room, player, now);
    collectEnergy(room, player);
  });
  updateBullets(room, now, delta);
  while (room.energy.length < 80) room.energy.push(createEnergy());
}
function shoot(room, player, now) { player.lastShot = now; room.bullets.push({ id: id('shot'), owner: player.id, x: player.x + Math.cos(player.angle) * 30, y: player.y + Math.sin(player.angle) * 30, vx: Math.cos(player.angle) * 590, vy: Math.sin(player.angle) * 590, expiresAt: now + 900, damage: 18 + player.level * 2 }); }
function collectEnergy(room, player) { for (let index = room.energy.length - 1; index >= 0; index -= 1) { const orb = room.energy[index]; if (Math.hypot(player.x - orb.x, player.y - orb.y) < 29) { room.energy.splice(index, 1); player.xp += 12; player.score += 12; if (player.xp >= player.xpNext) levelUp(player); } } }
function levelUp(player) { player.xp -= player.xpNext; player.level += 1; player.xpNext = Math.floor(player.xpNext * 1.25); player.maxHealth += 18; player.health = player.maxHealth; player.speed += 10; player.fireDelay = Math.max(150, player.fireDelay - 28); if (player.socket.readyState === WebSocket.OPEN) player.socket.send(JSON.stringify({ type: 'notice', message: `Livello ${player.level}! Scudo, velocità e fuoco potenziati.` })); }
function updateBullets(room, now, delta) { room.bullets = room.bullets.filter((bullet) => { bullet.x += bullet.vx * delta; bullet.y += bullet.vy * delta; if (now > bullet.expiresAt || bullet.x < 0 || bullet.y < 0 || bullet.x > WORLD_SIZE || bullet.y > WORLD_SIZE) return false; for (const target of room.players.values()) { if (target.id === bullet.owner || target.respawnAt) continue; if (Math.hypot(target.x - bullet.x, target.y - bullet.y) < 25) { target.health -= bullet.damage; const attacker = room.players.get(bullet.owner); if (target.health <= 0) destroyPlayer(target, attacker); return false; } } return true; }); }
function destroyPlayer(target, attacker) { target.respawnAt = Date.now() + 2200; target.health = 0; target.score = Math.max(0, target.score - 20); if (attacker) { attacker.score += 80; attacker.xp += 35; if (attacker.xp >= attacker.xpNext) levelUp(attacker); } }
function respawn(player) { player.respawnAt = 0; player.x = random(150, WORLD_SIZE - 150); player.y = random(150, WORLD_SIZE - 150); player.health = player.maxHealth; }
function snapshot(room) { const players = [...room.players.values()].map(({ id: playerId, nickname, skin: playerSkin, x, y, angle, health, maxHealth, xp, xpNext, level, score }) => ({ id: playerId, nickname, skin: playerSkin, x: Math.round(x), y: Math.round(y), angle, health, maxHealth, xp, xpNext, level, score })); const leaderboard = [...players].sort((first, second) => second.score - first.score).slice(0, 5).map(({ nickname, score }) => ({ nickname, score })); return { type: 'state', world: WORLD_SIZE, players, bullets: room.bullets.map(({ id: bulletId, owner, x, y }) => ({ id: bulletId, owner, x, y })), energy: room.energy, leaderboard }; }

let previousTick = Date.now(); let tick = 0;
setInterval(() => { const now = Date.now(); const delta = Math.min(.1, (now - previousTick) / 1000); previousTick = now; rooms.forEach((room) => { tickRoom(room, now, delta); tick += 1; if (tick % SNAPSHOT_EVERY_TICKS === 0) broadcast(room, snapshot(room)); }); }, 1000 / TICK_RATE);
server.listen(PORT, () => console.log(`Ship.io server in ascolto su ws://localhost:${PORT}`));
