const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { WebSocketServer, WebSocket } = require('ws');
const auth = require('./auth');

const PORT = Number(process.env.PORT || 3001);
const HOST = process.env.HOST || '0.0.0.0';
const TICK_RATE = 30;
const SNAPSHOT_EVERY_TICKS = 2;
const PROJECT_ROOT = path.resolve(__dirname, '../../..');
const rooms = new Map();
let roomSequence = 1;
let entitySequence = 1;

// The server owns the room population and the simulation. Clients only send intent.
const ARCADE_GAMES = [
  ['neon_dodge', 'Neon Dodge'], ['meteor_dash', 'Meteor Dash'], ['orbital_hoops', 'Orbital Hoops'], ['pixel_raiders', 'Pixel Raiders'],
  ['maze_rush', 'Maze Rush'], ['drift_nova', 'Drift Nova'], ['turbo_towers', 'Turbo Towers'], ['echo_jump', 'Echo Jump'],
  ['bubble_blitz', 'Bubble Blitz'], ['circuit_sprint', 'Circuit Sprint'], ['crystal_catch', 'Crystal Catch'], ['lava_hop', 'Lava Hop'],
  ['star_slinger', 'Star Slinger'], ['shadow_chase', 'Shadow Chase'], ['skyline_run', 'Skyline Run'], ['void_survivor', 'Void Survivor'],
  ['rocket_rally', 'Rocket Rally'], ['prism_puzzle', 'Prism Puzzle'], ['cosmo_pong', 'Cosmo Pong'], ['drone_arena', 'Drone Arena'],
];
const ARCADE_CONFIG = Object.fromEntries(ARCADE_GAMES.map(([id, label], index) => [id, {
  label, world: 1000, maxPlayers: 12, energyTarget: 24, speed: 230,
  botNames: [`BOT-${index + 1}`, 'NOVA', 'PULSE', 'BYTE', 'ECHO', 'VOLT', 'LUMA', 'ZIG'], arcade: true,
}]));

const GAME_CONFIG = {
  ship: { label: 'Ship.io', world: 2600, maxPlayers: 20, energyTarget: 80, speed: 185, botNames: ['NOVA', 'PULSE', 'ORBIT', 'BYTE', 'KRAKEN', 'LUMA', 'ZERO', 'VOLT'] },
  slither: { label: 'Slither.io', world: 5200, maxPlayers: 20, energyTarget: 160, speed: 170, botNames: ['MINT', 'COBRA', 'VIRUS', 'ECHO', 'GLOW', 'PIXEL', 'LUX', 'NOVA'] },
  parkour: { label: 'Crono Parkour', world: 120, maxPlayers: 20, energyTarget: 0, speed: 8.5, botNames: ['RUNNER', 'DASH', 'FLUX', 'HOP', 'RUSH', 'VEX', 'ZIG', 'RIFT'] },
  anonymous_runner: { label: 'Anonymous Runner', world: 120, maxPlayers: 20, energyTarget: 0, speed: 8.5, botNames: ['GHOST', 'NULL', 'CIPHER', 'SHADE', 'NOVA', 'VEX', 'RIFT', 'ECHO'] },
  ...ARCADE_CONFIG,
};

const server = http.createServer(async (request, response) => {
  const pathname = new URL(request.url, `http://${request.headers.host || 'localhost'}`).pathname;
  if (pathname === '/health') return sendJson(response, 200, { ok: true, rooms: [...rooms.values()].map(roomSummary) });
  if (pathname.startsWith('/api/')) return handleApi(request, response, pathname);

  const requestedFile = pathname === '/' ? '/web/index.html' : pathname;
  if (!requestedFile.startsWith('/web/') && !requestedFile.startsWith('/games/')) return response.writeHead(404).end();
  const filePath = path.resolve(PROJECT_ROOT, `.${requestedFile}`);
  if (!filePath.startsWith(`${PROJECT_ROOT}${path.sep}`)) return response.writeHead(403).end();

  fs.stat(filePath, (error, stats) => {
    if (error || !stats.isFile()) return response.writeHead(404).end();
    const contentTypes = {
      '.css': 'text/css; charset=utf-8', '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
      '.json': 'application/json; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
    };
    response.writeHead(200, { 'content-type': contentTypes[path.extname(filePath)] || 'application/octet-stream', 'cache-control': 'no-store' });
    fs.createReadStream(filePath).pipe(response);
  });
});
const websocketServer = new WebSocketServer({ server, maxPayload: 16_384 });

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
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { throw new Error('Dati non validi.'); }
}

async function handleApi(request, response, pathname) {
  try {
    if (request.method === 'POST' && pathname === '/api/rooms/create') {
      const body = await readJson(request);
      const game = gameFrom(body.game);
      let code = roomCode(body.code);
      if (!code) code = makeRoomCode();
      if ([...rooms.values()].some((room) => room.code === code)) return sendJson(response, 409, { error: 'Codice già in uso. Riprova.' });
      const room = createRoom(game, code);
      ensureBots(room);
      const host = String(request.headers.host || `localhost:${PORT}`).replace(/[^a-zA-Z0-9.:[\]-]/g, '');
      const protocol = request.headers['x-forwarded-proto'] === 'https' ? 'https' : 'http';
      const preferredLanUrl = localNetworkUrls()[0];
      const inviteOrigin = /^(localhost|127\.0\.0\.1)(?::\d+)?$/i.test(host) && preferredLanUrl ? new URL(preferredLanUrl).origin : `${protocol}://${host}`;
      const inviteUrl = `${inviteOrigin}/web/index.html?game=${encodeURIComponent(game)}&room=${encodeURIComponent(code)}`;
      return sendJson(response, 201, { room: roomSummary(room), code, inviteUrl });
    }
    const token = auth.readCookie(request.headers.cookie, 'cg_session');
    if (request.method === 'GET' && pathname === '/api/auth/me') return sendJson(response, 200, { account: await auth.accountFromSession(token) });
    if (request.method === 'POST' && pathname === '/api/auth/register') {
      const body = await readJson(request);
      const account = await auth.register(body.username, body.password);
      return sendJson(response, 201, { account }, { 'set-cookie': auth.sessionCookie(auth.createSession(account.id)) });
    }
    if (request.method === 'POST' && pathname === '/api/auth/login') {
      const body = await readJson(request);
      const account = await auth.login(body.username, body.password);
      if (!account) return sendJson(response, 401, { error: 'Credenziali non valide.' });
      return sendJson(response, 200, { account }, { 'set-cookie': auth.sessionCookie(auth.createSession(account.id)) });
    }
    if (request.method === 'POST' && pathname === '/api/auth/logout') {
      auth.removeSession(token);
      return sendJson(response, 200, { ok: true }, { 'set-cookie': auth.expiredSessionCookie() });
    }
    return sendJson(response, 404, { error: 'Endpoint non trovato.' });
  } catch (error) {
    const clientError = /nome utente|password|uso|troppo grande|Dati non validi/i.test(error.message);
    return sendJson(response, clientError ? 400 : 500, { error: clientError ? error.message : 'Errore del server.' });
  }
}

function random(min, max) { return Math.random() * (max - min) + min; }
function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }
function id(prefix) { entitySequence += 1; return `${prefix}-${entitySequence.toString(36)}`; }
function safeNickname(value, fallback = 'Pilota') { return String(value || fallback).trim().replace(/[<>]/g, '').slice(0, 16) || fallback; }
function safeSkin(value) { return ['violet', 'cyan', 'amber', 'mint', 'pink', 'sky', 'gold'].includes(value) ? value : 'violet'; }
function gameFrom(value) { return Object.hasOwn(GAME_CONFIG, value) ? value : 'ship'; }
function roomCode(value) { const code = String(value || '').toUpperCase().replace(/[^A-Z2-9]/g, '').slice(0, 8); return code.length >= 5 ? code : ''; }
function makeRoomCode() { const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; let code = ''; do { code = Array.from({ length: 6 }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join(''); } while ([...rooms.values()].some((room) => room.code === code)); return code; }

function createRoom(game, code = '') {
  const config = GAME_CONFIG[game];
  const room = { id: `${game}-${roomSequence++}`, code, game, config, players: new Map(), bullets: [], energy: [], lastSpawn: 0 };
  for (let index = 0; index < config.energyTarget; index += 1) room.energy.push(createEnergy(room));
  rooms.set(room.id, room);
  return room;
}

function findRoom(game, requestedCode = '') {
  if (requestedCode) return [...rooms.values()].find((room) => room.game === game && room.code === requestedCode) || null;
  return [...rooms.values()].find((room) => room.game === game && humanCount(room) < room.config.maxPlayers) || createRoom(game);
}

function isRunnerGame(game) { return game === 'parkour' || game === 'anonymous_runner'; }
function isArcadeGame(game) { return Boolean(GAME_CONFIG[game]?.arcade); }
function createEnergy(room) {
  const edge = isRunnerGame(room.game) ? 8 : 65;
  return { id: id('orb'), x: random(edge, room.config.world - edge), y: random(edge, room.config.world - edge) };
}

function createPlayer(socket, payload, room, bot = false) {
  const config = room.config;
  const margin = isRunnerGame(room.game) ? 8 : 150;
  const botIndex = room.players.size % config.botNames.length;
  return {
    id: id(bot ? 'bot' : 'pilot'), socket: bot ? null : socket, bot,
    nickname: bot ? config.botNames[botIndex] : safeNickname(payload.nickname), skin: safeSkin(payload.skin),
    x: random(margin, config.world - margin), y: random(margin, config.world - margin), angle: random(-Math.PI, Math.PI),
    health: 100, maxHealth: 100, xp: 0, xpNext: 100, level: 1, score: bot ? Math.floor(random(0, 80)) : 0,
    length: room.game === 'slither' ? Math.floor(random(28, 54)) : 0,
    speed: config.speed, fireDelay: 380, lastShot: 0, respawnAt: 0,
    input: { keys: [], angle: 0, shooting: false, jumping: false }, botTurnAt: 0,
  };
}

function humanCount(room) { return [...room.players.values()].filter((player) => !player.bot).length; }
function ensureBots(room) {
  while (room.players.size < room.config.maxPlayers) {
    const bot = createPlayer(null, {}, room, true);
    room.players.set(bot.id, bot);
  }
}
function removeOneBot(room) {
  const bot = [...room.players.values()].find((player) => player.bot);
  if (bot) room.players.delete(bot.id);
}
function roomSummary(room) { return { id: room.id, code: room.code || null, game: room.game, players: room.players.size, humans: humanCount(room), capacity: room.config.maxPlayers }; }
function send(socket, message) { if (socket && socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message)); }
function broadcast(room, message) { room.players.forEach((player) => send(player.socket, message)); }

function leaveRoom(player) {
  if (!player?.room) return;
  const room = player.room;
  room.players.delete(player.id);
  if (humanCount(room) === 0) rooms.delete(room.id);
  else ensureBots(room);
  player.room = null;
}

websocketServer.on('connection', (socket) => {
  let player = null;
  socket.on('message', (raw) => {
    let message;
    try { message = JSON.parse(raw.toString()); } catch { return; }
    if (message.type === 'join' && !player) {
      const game = gameFrom(message.game);
      const requestedCode = roomCode(message.roomCode);
      const room = findRoom(game, requestedCode);
      if (!room) return send(socket, { type: 'error', code: 'room_not_found', message: 'Stanza non trovata: verifica il codice.' });
      if (humanCount(room) >= room.config.maxPlayers) return send(socket, { type: 'error', code: 'room_full', message: 'La stanza è piena.' });
      removeOneBot(room);
      player = createPlayer(socket, message, room);
      player.room = room;
      room.players.set(player.id, player);
      ensureBots(room);
      send(socket, { type: 'joined', id: player.id, roomId: room.id, roomCode: room.code || null, game, world: room.config.world, capacity: room.config.maxPlayers });
      broadcast(room, { type: 'notice', message: `${player.nickname} è entrato in ${room.id}.` });
      return;
    }
    if (message.type === 'input' && player && Array.isArray(message.keys)) {
      player.input = {
        keys: message.keys.filter((key) => typeof key === 'string').slice(0, 8),
        angle: Number.isFinite(message.angle) ? message.angle : player.angle,
        shooting: Boolean(message.shooting), jumping: Boolean(message.jumping),
      };
    }
    if (message.type === 'leave') leaveRoom(player);
  });
  socket.on('close', () => leaveRoom(player));
  socket.on('error', () => leaveRoom(player));
});

function botInput(room, player, now) {
  if (now >= player.botTurnAt) {
    player.botTurnAt = now + random(700, 2100);
    player.input.angle = random(-Math.PI, Math.PI);
    const styles = isRunnerGame(room.game) ? [['w'], ['d'], ['w', 'd'], ['a']] : [['w'], ['a'], ['s'], ['d'], ['w', 'd'], ['w', 'a']];
    player.input.keys = styles[Math.floor(Math.random() * styles.length)];
    player.input.shooting = room.game === 'ship' || (isArcadeGame(room.game) && Math.random() > 0.66);
    player.input.jumping = (isRunnerGame(room.game) || isArcadeGame(room.game)) && Math.random() > 0.72;
  }
}

function movementFromInput(player) {
  const keys = new Set(player.input.keys);
  const horizontal = Number(keys.has('d') || keys.has('ArrowRight')) - Number(keys.has('a') || keys.has('ArrowLeft'));
  const vertical = Number(keys.has('s') || keys.has('ArrowDown')) - Number(keys.has('w') || keys.has('ArrowUp'));
  return { horizontal, vertical, magnitude: Math.hypot(horizontal, vertical) || 1 };
}

function tickPlayer(room, player, now, delta) {
  if (player.bot) botInput(room, player, now);
  if (player.respawnAt) {
    if (now >= player.respawnAt) respawn(room, player);
    else return;
  }
  const { horizontal, vertical, magnitude } = movementFromInput(player);
  player.x = clamp(player.x + (horizontal / magnitude) * player.speed * delta, 25, room.config.world - 25);
  player.y = clamp(player.y + (vertical / magnitude) * player.speed * delta, 25, room.config.world - 25);
  player.angle = clamp(Number(player.input.angle) || player.angle, -Math.PI * 2, Math.PI * 2);
  if (room.game === 'ship') {
    if (player.input.shooting && now - player.lastShot >= player.fireDelay) shoot(room, player, now);
    collectEnergy(room, player);
  } else if (room.game === 'slither') {
    collectEnergy(room, player);
    player.length = Math.max(20, player.length + (player.input.shooting ? -0.012 : 0));
  } else if (isArcadeGame(room.game)) {
    collectEnergy(room, player);
    if (player.input.jumping || player.input.shooting) player.score += delta * 4;
  } else if (player.input.jumping) {
    player.score += delta * 4;
  }
}

function tickRoom(room, now, delta) {
  room.players.forEach((player) => tickPlayer(room, player, now, delta));
  if (room.game === 'ship') updateBullets(room, now, delta);
  while (room.energy.length < room.config.energyTarget) room.energy.push(createEnergy(room));
}

function shoot(room, player, now) {
  player.lastShot = now;
  room.bullets.push({ id: id('shot'), owner: player.id, x: player.x + Math.cos(player.angle) * 30, y: player.y + Math.sin(player.angle) * 30, vx: Math.cos(player.angle) * 590, vy: Math.sin(player.angle) * 590, expiresAt: now + 900, damage: 18 + player.level * 2 });
}
function collectEnergy(room, player) {
  for (let index = room.energy.length - 1; index >= 0; index -= 1) {
    const orb = room.energy[index];
    if (Math.hypot(player.x - orb.x, player.y - orb.y) >= 30) continue;
    room.energy.splice(index, 1);
    player.xp += room.game === 'slither' ? 4 : 12;
    player.score += room.game === 'slither' ? 5 : 12;
    if (room.game === 'slither') player.length += 1;
    if (player.xp >= player.xpNext) levelUp(player);
  }
}
function levelUp(player) {
  player.xp -= player.xpNext;
  player.level += 1;
  player.xpNext = Math.floor(player.xpNext * 1.25);
  player.maxHealth += 18;
  player.health = player.maxHealth;
  player.speed += 10;
  player.fireDelay = Math.max(150, player.fireDelay - 28);
  send(player.socket, { type: 'notice', message: `Livello ${player.level}! Potenziamento attivo.` });
}
function updateBullets(room, now, delta) {
  room.bullets = room.bullets.filter((bullet) => {
    bullet.x += bullet.vx * delta; bullet.y += bullet.vy * delta;
    if (now > bullet.expiresAt || bullet.x < 0 || bullet.y < 0 || bullet.x > room.config.world || bullet.y > room.config.world) return false;
    for (const target of room.players.values()) {
      if (target.id === bullet.owner || target.respawnAt) continue;
      if (Math.hypot(target.x - bullet.x, target.y - bullet.y) >= 25) continue;
      target.health -= bullet.damage;
      const attacker = room.players.get(bullet.owner);
      if (target.health <= 0) destroyPlayer(room, target, attacker);
      return false;
    }
    return true;
  });
}
function destroyPlayer(room, target, attacker) {
  target.respawnAt = Date.now() + 2200;
  target.health = 0;
  target.score = Math.max(0, target.score - 20);
  if (attacker) { attacker.score += 80; attacker.xp += 35; if (attacker.xp >= attacker.xpNext) levelUp(attacker); }
  if (!target.bot) send(target.socket, { type: 'notice', message: 'Sei stato eliminato: rientro tra 2 secondi.' });
}
function respawn(room, player) {
  player.respawnAt = 0;
  player.x = random(100, room.config.world - 100);
  player.y = random(100, room.config.world - 100);
  player.health = player.maxHealth;
}

function snapshot(room) {
  const players = [...room.players.values()].map((player) => ({
    id: player.id, nickname: player.nickname, skin: player.skin, bot: player.bot, x: Math.round(player.x * 10) / 10, y: Math.round(player.y * 10) / 10,
    angle: player.angle, health: Math.round(player.health), maxHealth: player.maxHealth, xp: player.xp, xpNext: player.xpNext,
    level: player.level, score: Math.floor(player.score), length: player.length, jumping: player.input.jumping, respawning: Boolean(player.respawnAt),
  }));
  const leaderboard = [...players].sort((first, second) => second.score - first.score).slice(0, 5).map(({ nickname, score, bot }) => ({ nickname, score, bot }));
  return { type: 'state', game: room.game, roomId: room.id, roomCode: room.code || null, world: room.config.world, capacity: room.config.maxPlayers, humans: humanCount(room), bots: room.players.size - humanCount(room), players, bullets: room.bullets.map(({ id: bulletId, owner, x, y }) => ({ id: bulletId, owner, x, y })), energy: room.energy, leaderboard };
}

let previousTick = Date.now();
let tick = 0;
setInterval(() => {
  const now = Date.now();
  const delta = Math.min(0.1, (now - previousTick) / 1000);
  previousTick = now;
  rooms.forEach((room) => {
    tickRoom(room, now, delta);
    tick += 1;
    if (tick % SNAPSHOT_EVERY_TICKS === 0) broadcast(room, snapshot(room));
  });
}, 1000 / TICK_RATE);

function localNetworkUrls() {
  const addresses = new Set();
  for (const network of Object.values(os.networkInterfaces())) {
    for (const address of network || []) {
      if (address.family === 'IPv4' && !address.internal) addresses.add(`http://${address.address}:${PORT}/web/index.html`);
    }
  }
  return [...addresses];
}

server.listen(PORT, HOST, () => {
  console.log(`CronoGames multiplayer server pronto su http://localhost:${PORT}`);
  console.log('Per giocare con amici sulla stessa Wi-Fi, condividi uno di questi indirizzi:');
  for (const url of localNetworkUrls()) console.log(`  ${url}`);
});
