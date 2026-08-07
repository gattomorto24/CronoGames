const GAME_LIBRARY = {
  neon_dodge: { title: 'Neon Dodge', subtitle: 'Schiva il blackout', mission: 'Evita i droni neon', mode: 'dodge', accent: '#6effd6', accent2: '#5d62ff' },
  meteor_dash: { title: 'Meteor Dash', subtitle: 'Corsa tra gli asteroidi', mission: 'Sfuggi ai meteoriti', mode: 'racer', accent: '#ffbd55', accent2: '#ff557f' },
  orbital_hoops: { title: 'Orbital Hoops', subtitle: 'Caccia all’orbita', mission: 'Raccogli gli anelli', mode: 'collector', accent: '#70e7ff', accent2: '#8c72ff' },
  pixel_raiders: { title: 'Pixel Raiders', subtitle: 'Invasione arcade', mission: 'Difendi il settore', mode: 'shooter', accent: '#f4ff65', accent2: '#ff6dcb' },
  maze_rush: { title: 'Maze Rush', subtitle: 'Labirinto a tempo', mission: 'Trova l’uscita', mode: 'maze', accent: '#ab86ff', accent2: '#60eeff' },
  drift_nova: { title: 'Drift Nova', subtitle: 'Curve in gravità zero', mission: 'Mantieni la traiettoria', mode: 'drift', accent: '#ff75ce', accent2: '#f8db69' },
  turbo_towers: { title: 'Turbo Towers', subtitle: 'Salita verticale', mission: 'Scala più in alto', mode: 'jumper', accent: '#ffc764', accent2: '#ff6c79' },
  echo_jump: { title: 'Echo Jump', subtitle: 'Salti a impulso', mission: 'Rimbalza sulle piattaforme', mode: 'platform', accent: '#71fff3', accent2: '#6376ff' },
  bubble_blitz: { title: 'Bubble Blitz', subtitle: 'Bolle instabili', mission: 'Scoppia le bolle', mode: 'bubble', accent: '#78e4ff', accent2: '#cc8dff' },
  circuit_sprint: { title: 'Circuit Sprint', subtitle: 'Giro perfetto', mission: 'Passa tutti i checkpoint', mode: 'sprint', accent: '#b0ff62', accent2: '#31bce8' },
  crystal_catch: { title: 'Crystal Catch', subtitle: 'Pioggia di cristalli', mission: 'Prendi i cristalli', mode: 'catch', accent: '#7df8ff', accent2: '#6384ff' },
  lava_hop: { title: 'Lava Hop', subtitle: 'La lava sale', mission: 'Non fermarti', mode: 'hop', accent: '#ffad5f', accent2: '#ff5b6d' },
  star_slinger: { title: 'Star Slinger', subtitle: 'Fionda cosmica', mission: 'Centra le stelle', mode: 'sling', accent: '#ffe168', accent2: '#fc79d7' },
  shadow_chase: { title: 'Shadow Chase', subtitle: 'Ombra in caccia', mission: 'Sfuggi alla tua ombra', mode: 'chase', accent: '#b88bff', accent2: '#4d5cff' },
  skyline_run: { title: 'Skyline Run', subtitle: 'Tetti al neon', mission: 'Salta gli ostacoli', mode: 'runner', accent: '#6dffbb', accent2: '#48a8ff' },
  void_survivor: { title: 'Void Survivor', subtitle: 'Nessun rifugio', mission: 'Resisti nel vuoto', mode: 'survivor', accent: '#ff77f3', accent2: '#8566ff' },
  rocket_rally: { title: 'Rocket Rally', subtitle: 'Rally interstellare', mission: 'Supera i rivali', mode: 'rally', accent: '#ff9b55', accent2: '#ffe66b' },
  prism_puzzle: { title: 'Prism Puzzle', subtitle: 'Sequenza di luce', mission: 'Ripeti la sequenza', mode: 'memory', accent: '#8fffe2', accent2: '#af7cff' },
  cosmo_pong: { title: 'Cosmo Pong', subtitle: 'Classico orbitale', mission: 'Non perdere la sfera', mode: 'pong', accent: '#77e7ff', accent2: '#7394ff' },
  drone_arena: { title: 'Drone Arena', subtitle: 'Duello tattico', mission: 'Abbatti i bersagli', mode: 'arena', accent: '#ffed72', accent2: '#ff6689' },
};

const query = new URLSearchParams(location.search);
const gameId = query.get('game') || 'neon_dodge';
const config = GAME_LIBRARY[gameId] || GAME_LIBRARY.neon_dodge;
const roomCode = String(query.get('room') || '').toUpperCase().replace(/[^A-Z2-9]/g, '').slice(0, 8);
const canvas = document.querySelector('#game');
const context = canvas.getContext('2d');
const shell = document.querySelector('#arcade-shell');
const welcome = document.querySelector('#welcome');
const nicknameInput = document.querySelector('#nickname');
const playButton = document.querySelector('#play');
const title = document.querySelector('#game-title');
const subtitle = document.querySelector('#game-subtitle');
const welcomeTitle = document.querySelector('#welcome-title');
const welcomeDescription = document.querySelector('#welcome-description');
const mission = document.querySelector('#mission');
const scoreElement = document.querySelector('#score');
const connectionElement = document.querySelector('#connection');
const playersPanel = document.querySelector('#players-panel');
const roomLabel = document.querySelector('#room-label');
const population = document.querySelector('#population');
const leaderboard = document.querySelector('#leaderboard');
const leaderboardList = document.querySelector('#leaderboard-list');
const notice = document.querySelector('#notice');
const stick = document.querySelector('#touch-stick');
const knob = document.querySelector('#touch-knob');
const actionButton = document.querySelector('#touch-action');

document.documentElement.style.setProperty('--accent', config.accent);
document.documentElement.style.setProperty('--accent-2', config.accent2);
document.title = `${config.title} — CronoGames`;
title.textContent = config.title;
subtitle.textContent = config.subtitle;
welcomeTitle.textContent = config.title;
welcomeDescription.textContent = `${config.subtitle}. ${roomCode ? `Stanza privata ${roomCode}.` : 'Partita rapida disponibile.'}`;
mission.textContent = config.mission;
nicknameInput.value = localStorage.getItem('cronogames_arcade_nickname') || `Player${Math.floor(100 + Math.random() * 900)}`;

const state = {
  started: false, lastTime: 0, score: 0, world: 1000, socket: null, online: false, playerId: '', remote: null,
  keys: new Set(), touch: { x: 0, y: 0 }, player: { x: 500, y: 500, r: 20, vx: 0, vy: 0, facing: 0 },
  targets: [], hazards: [], particles: [], shots: [], platforms: [], maze: [], ball: null, sequence: [], sequenceIndex: 0,
  actionQueued: false, elapsed: 0, nextSpawn: 0, lastNetworkInput: 0, localHighScore: 0,
};

function localNetworkHost() {
  const host = location.hostname;
  return host === 'localhost' || /^127\./.test(host) || /^10\./.test(host) || /^192\.168\./.test(host) || /^172\.(1[6-9]|2\d|3[0-1])\./.test(host) || host.endsWith('.local');
}
function random(min, max) { return Math.random() * (max - min) + min; }
function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }
function distance(one, two) { return Math.hypot(one.x - two.x, one.y - two.y); }
function isActionDown() { return state.keys.has(' ') || state.keys.has('Enter') || state.actionQueued; }
function showNotice(message) { notice.textContent = message; notice.classList.add('show'); clearTimeout(showNotice.timer); showNotice.timer = setTimeout(() => notice.classList.remove('show'), 1800); }
function addScore(value) { state.score += value; scoreElement.textContent = String(Math.floor(state.score)).padStart(4, '0'); }
function keysForServer() { const keys = []; if (state.keys.has('w') || state.keys.has('ArrowUp') || state.touch.y < -.2) keys.push('w'); if (state.keys.has('s') || state.keys.has('ArrowDown') || state.touch.y > .2) keys.push('s'); if (state.keys.has('a') || state.keys.has('ArrowLeft') || state.touch.x < -.2) keys.push('a'); if (state.keys.has('d') || state.keys.has('ArrowRight') || state.touch.x > .2) keys.push('d'); return keys; }

function resize() { const ratio = Math.min(window.devicePixelRatio || 1, 2); canvas.width = Math.floor(innerWidth * ratio); canvas.height = Math.floor(innerHeight * ratio); canvas.style.width = `${innerWidth}px`; canvas.style.height = `${innerHeight}px`; context.setTransform(ratio, 0, 0, ratio, 0, 0); }
window.addEventListener('resize', resize); resize();

function createTarget(kind = 'orb') { return { x: random(80, state.world - 80), y: random(90, state.world - 90), r: random(13, 25), kind, vx: random(-90, 90), vy: random(-90, 90), life: random(3, 8), hue: random(0, 360) }; }
function createHazard(kind = 'hazard') { const side = Math.floor(Math.random() * 4); const position = side === 0 ? { x: random(0, state.world), y: -30 } : side === 1 ? { x: state.world + 30, y: random(0, state.world) } : side === 2 ? { x: random(0, state.world), y: state.world + 30 } : { x: -30, y: random(0, state.world) }; const angle = Math.atan2(state.player.y - position.y, state.player.x - position.x) + random(-.7, .7); return { ...position, r: random(14, 31), kind, vx: Math.cos(angle) * random(80, 180), vy: Math.sin(angle) * random(80, 180), life: random(4, 11), hue: random(0, 360) }; }
function resetMode() {
  state.targets = []; state.hazards = []; state.shots = []; state.particles = []; state.platforms = []; state.maze = []; state.score = 0; state.elapsed = 0; state.nextSpawn = 0; state.sequence = []; state.sequenceIndex = 0; scoreElement.textContent = '0000'; state.player.x = 500; state.player.y = 600; state.player.vx = 0; state.player.vy = 0;
  if (['collector', 'catch', 'bubble', 'sprint'].includes(config.mode)) for (let index = 0; index < 14; index += 1) state.targets.push(createTarget(config.mode));
  if (['dodge', 'survivor', 'chase', 'racer', 'drift', 'rally', 'runner', 'hop'].includes(config.mode)) for (let index = 0; index < 7; index += 1) state.hazards.push(createHazard(config.mode));
  if (['shooter', 'arena', 'sling'].includes(config.mode)) for (let index = 0; index < 10; index += 1) state.targets.push(createTarget('enemy'));
  if (config.mode === 'maze') { for (let index = 0; index < 12; index += 1) state.maze.push({ x: 120 + (index % 4) * 195, y: 115 + Math.floor(index / 4) * 235, w: index % 2 ? 130 : 30, h: index % 2 ? 30 : 140 }); state.targets.push({ x: 870, y: 125, r: 25, kind: 'exit', vx: 0, vy: 0 }); }
  if (['jumper', 'platform', 'hop'].includes(config.mode)) { state.player.y = 800; state.platforms = Array.from({ length: 10 }, (_, index) => ({ x: 70 + ((index * 179) % 730), y: 870 - index * 90, w: 155, h: 16 })); }
  if (config.mode === 'pong') state.ball = { x: 500, y: 500, vx: 300, vy: 130, r: 13, opponent: 460, playerPaddle: 460 };
  if (config.mode === 'memory') { state.sequence = Array.from({ length: 4 }, () => Math.floor(Math.random() * 4)); state.sequenceIndex = 0; showNotice('Memorizza i colori, poi premi AZIONE.'); }
}

function start() {
  state.started = true; state.lastTime = performance.now(); localStorage.setItem('cronogames_arcade_nickname', nicknameInput.value.trim() || 'Player'); welcome.hidden = true; resetMode(); connectOnline(); requestAnimationFrame(loop);
}
playButton.addEventListener('click', start);
nicknameInput.addEventListener('keydown', (event) => { if (event.key === 'Enter') start(); });

function connectOnline() {
  if (!localNetworkHost()) { connectionElement.textContent = 'SOLO · PAGES'; return; }
  const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
  try { state.socket = new WebSocket(`${protocol}//${location.host}`); } catch { connectionElement.textContent = 'SOLO'; return; }
  state.socket.addEventListener('open', () => { state.socket.send(JSON.stringify({ type: 'join', game: gameId, roomCode, nickname: nicknameInput.value.trim() || 'Player', skin: 'cyan' })); });
  state.socket.addEventListener('message', ({ data }) => { let message; try { message = JSON.parse(data); } catch { return; } handleNetwork(message); });
  state.socket.addEventListener('close', () => { if (state.online) showNotice('Connessione chiusa: continui in locale.'); state.online = false; connectionElement.textContent = 'SOLO'; playersPanel.hidden = true; leaderboard.hidden = true; });
  state.socket.addEventListener('error', () => { connectionElement.textContent = 'SOLO'; });
}
function handleNetwork(message) {
  if (message.type === 'joined') { state.online = true; state.playerId = message.id; state.world = message.world; connectionElement.textContent = message.roomCode ? `ONLINE · ${message.roomCode}` : 'ONLINE'; playersPanel.hidden = false; leaderboard.hidden = false; roomLabel.textContent = message.roomCode ? `STANZA ${message.roomCode}` : 'ARENA PUBBLICA'; return; }
  if (message.type === 'state') { state.remote = message; population.textContent = `${message.humans} giocator${message.humans === 1 ? 'e' : 'i'} · ${message.bots} bot`; leaderboardList.replaceChildren(...message.leaderboard.map((entry) => { const item = document.createElement('li'); item.textContent = `${entry.bot ? '◌ ' : ''}${entry.nickname}`; const score = document.createElement('b'); score.textContent = entry.score; item.append(score); return item; })); const me = message.players.find((entry) => entry.id === state.playerId); if (me) { state.player.x = me.x; state.player.y = me.y; } }
  if (message.type === 'notice' || message.type === 'error') showNotice(message.message);
}

function updateInput(dt) {
  const keys = keysForServer(); const horizontal = Number(keys.includes('d')) - Number(keys.includes('a')); const vertical = Number(keys.includes('s')) - Number(keys.includes('w')); const magnitude = Math.hypot(horizontal, vertical) || 1; const speed = config.mode === 'racer' || config.mode === 'rally' ? 310 : 250;
  if (!state.online) { state.player.x = clamp(state.player.x + horizontal / magnitude * speed * dt, 28, state.world - 28); state.player.y = clamp(state.player.y + vertical / magnitude * speed * dt, 28, state.world - 28); }
  if (horizontal || vertical) state.player.facing = Math.atan2(vertical, horizontal);
  if (state.online && performance.now() - state.lastNetworkInput > 58 && state.socket?.readyState === WebSocket.OPEN) { state.lastNetworkInput = performance.now(); state.socket.send(JSON.stringify({ type: 'input', keys, angle: state.player.facing, shooting: isActionDown(), jumping: isActionDown() })); }
}
function particle(x, y, color = config.accent, amount = 9) { for (let index = 0; index < amount; index += 1) state.particles.push({ x, y, vx: random(-160, 160), vy: random(-160, 160), life: random(.25, .7), color }); }
function fail(message = 'Colpo subito!') { particle(state.player.x, state.player.y, '#ff5e85', 16); state.score = Math.max(0, state.score - 15); scoreElement.textContent = String(Math.floor(state.score)).padStart(4, '0'); state.player.x = 500; state.player.y = 620; showNotice(message); }

function moveObjects(dt, objects, bounce = false) { objects.forEach((object) => { object.x += object.vx * dt; object.y += object.vy * dt; object.life -= dt; if (bounce && (object.x < 25 || object.x > state.world - 25)) object.vx *= -1; if (bounce && (object.y < 25 || object.y > state.world - 25)) object.vy *= -1; }); return objects.filter((object) => object.life > 0); }
function updateStandard(dt, kind) {
  state.elapsed += dt; state.nextSpawn -= dt; if (state.nextSpawn <= 0) { state.nextSpawn = kind === 'survivor' ? .45 : .9; state.hazards.push(createHazard(kind)); }
  state.hazards = moveObjects(dt, state.hazards); state.hazards.forEach((hazard) => { if (distance(state.player, hazard) < state.player.r + hazard.r) fail('Impatto! Riprova.'); }); addScore(dt * (kind === 'racer' || kind === 'rally' ? 12 : 7));
}
function updateCollect(dt) { state.targets = moveObjects(dt, state.targets, true); state.targets.forEach((target) => { if (distance(state.player, target) < state.player.r + target.r) { target.life = 0; addScore(25); particle(target.x, target.y); } }); if (state.targets.length < 11) state.targets.push(createTarget(config.mode)); }
function fireShot() { state.actionQueued = false; state.shots.push({ x: state.player.x, y: state.player.y, vx: Math.cos(state.player.facing) * 620, vy: Math.sin(state.player.facing) * 620, life: 1.3 }); }
function updateShooter(dt) { if (isActionDown() && state.shots.length < 3) fireShot(); state.targets = moveObjects(dt, state.targets, true); state.shots = moveObjects(dt, state.shots); state.shots.forEach((shot) => state.targets.forEach((target) => { if (target.life > 0 && distance(shot, target) < target.r + 8) { target.life = 0; shot.life = 0; addScore(30); particle(target.x, target.y, '#fff27a'); } })); if (state.targets.length < 8) state.targets.push(createTarget('enemy')); }
function updateMaze(dt) { const exit = state.targets[0]; if (exit && distance(state.player, exit) < 50) { addScore(120); showNotice('Uscita trovata! Nuovo labirinto.'); resetMode(); } state.maze.forEach((wall) => { const nearX = clamp(state.player.x, wall.x, wall.x + wall.w); const nearY = clamp(state.player.y, wall.y, wall.y + wall.h); if (Math.hypot(state.player.x - nearX, state.player.y - nearY) < state.player.r) fail('Muro energetico!'); }); addScore(dt * 3); }
function updatePlatform(dt) { const wantsJump = isActionDown(); state.actionQueued = false; state.player.vy += 780 * dt; if (wantsJump && state.player.vy > -40) state.player.vy = -410; state.player.y += state.player.vy * dt; state.platforms.forEach((platform) => { if (state.player.vy > 0 && state.player.x > platform.x && state.player.x < platform.x + platform.w && state.player.y + state.player.r > platform.y && state.player.y < platform.y + platform.h + 18) { state.player.y = platform.y - state.player.r; state.player.vy = -430; addScore(12); } }); if (state.player.y > 1040) { fail('Caduta!'); state.player.y = 800; state.player.vy = 0; } addScore(dt * 4); }
function updatePong(dt) { const ball = state.ball; ball.playerPaddle = clamp(state.player.y - 58, 70, 840); ball.opponent += clamp(ball.y - (ball.opponent + 58), -210 * dt, 210 * dt); ball.x += ball.vx * dt; ball.y += ball.vy * dt; if (ball.y < 20 || ball.y > 980) ball.vy *= -1; if (ball.x < 65 && ball.y > ball.playerPaddle - 15 && ball.y < ball.playerPaddle + 130) { ball.vx = Math.abs(ball.vx) * 1.06; addScore(10); } if (ball.x > 935 && ball.y > ball.opponent - 15 && ball.y < ball.opponent + 130) ball.vx = -Math.abs(ball.vx) * 1.04; if (ball.x < -20) { fail('Palla persa!'); Object.assign(ball, { x: 500, y: 500, vx: 300, vy: 130 }); } if (ball.x > 1020) { addScore(80); Object.assign(ball, { x: 500, y: 500, vx: -300, vy: random(-180, 180) }); } }
function updateMemory() { if (isActionDown()) { state.actionQueued = false; const expected = state.sequence[state.sequenceIndex]; const selected = Math.floor((state.player.x / state.world) * 4); if (selected === expected) { state.sequenceIndex += 1; addScore(25); if (state.sequenceIndex >= state.sequence.length) { state.sequence.push(Math.floor(Math.random() * 4)); state.sequenceIndex = 0; addScore(100); showNotice('Sequenza aumentata.'); } } else { state.sequenceIndex = 0; fail('Sequenza errata.'); } } }
function updateBubble(dt) { state.targets = moveObjects(dt, state.targets, true); if (isActionDown()) { state.actionQueued = false; const closest = [...state.targets].sort((a, b) => distance(a, state.player) - distance(b, state.player))[0]; if (closest && distance(closest, state.player) < 150) { closest.life = 0; addScore(20); particle(closest.x, closest.y, config.accent); } } if (state.targets.length < 10) state.targets.push(createTarget('bubble')); }
function updateChase(dt) { if (!state.hazards.length) state.hazards.push({ x: 800, y: 200, r: 32, life: 999, vx: 0, vy: 0, kind: 'shadow' }); const shadow = state.hazards[0]; const angle = Math.atan2(state.player.y - shadow.y, state.player.x - shadow.x); shadow.x += Math.cos(angle) * 150 * dt; shadow.y += Math.sin(angle) * 150 * dt; if (distance(state.player, shadow) < 48) fail('L’ombra ti ha trovato!'); addScore(dt * 11); }
function updateGame(dt) {
  updateInput(dt);
  if (['dodge', 'survivor', 'racer', 'drift', 'rally', 'runner'].includes(config.mode)) { updateStandard(dt, config.mode); state.actionQueued = false; }
  else if (['collector', 'catch', 'sprint'].includes(config.mode)) updateCollect(dt);
  else if (['shooter', 'arena', 'sling'].includes(config.mode)) updateShooter(dt);
  else if (config.mode === 'maze') updateMaze(dt);
  else if (['jumper', 'platform', 'hop'].includes(config.mode)) updatePlatform(dt);
  else if (config.mode === 'pong') updatePong(dt);
  else if (config.mode === 'memory') updateMemory(dt);
  else if (config.mode === 'bubble') updateBubble(dt);
  else if (config.mode === 'chase') updateChase(dt);
  else state.actionQueued = false;
  state.particles = state.particles.filter((entry) => { entry.x += entry.vx * dt; entry.y += entry.vy * dt; entry.life -= dt; return entry.life > 0; });
}

function camera() { const scale = Math.min(innerWidth, innerHeight) / 1000; return { scale: Math.max(.45, scale), x: innerWidth / 2 - state.player.x * Math.max(.45, scale), y: innerHeight / 2 - state.player.y * Math.max(.45, scale) }; }
function worldPoint(point, cam) { return { x: point.x * cam.scale + cam.x, y: point.y * cam.scale + cam.y }; }
function drawCircle(point, radius, color, cam, glow = 0) { const position = worldPoint(point, cam); context.save(); if (glow) { context.shadowBlur = glow * cam.scale; context.shadowColor = color; } context.fillStyle = color; context.beginPath(); context.arc(position.x, position.y, radius * cam.scale, 0, Math.PI * 2); context.fill(); context.restore(); }
function drawBackground(cam) { context.clearRect(0, 0, innerWidth, innerHeight); const grid = 100 * cam.scale; context.save(); context.strokeStyle = 'rgba(160,177,255,.09)'; context.lineWidth = 1; for (let x = (cam.x % grid) - grid; x < innerWidth + grid; x += grid) { context.beginPath(); context.moveTo(x, 0); context.lineTo(x, innerHeight); context.stroke(); } for (let y = (cam.y % grid) - grid; y < innerHeight + grid; y += grid) { context.beginPath(); context.moveTo(0, y); context.lineTo(innerWidth, y); context.stroke(); } context.strokeStyle = config.accent; context.globalAlpha = .45; context.strokeRect(cam.x, cam.y, state.world * cam.scale, state.world * cam.scale); context.restore(); }
function drawObjects(cam) { state.maze.forEach((wall) => { const p = worldPoint(wall, cam); context.fillStyle = 'rgba(169, 134, 255, .42)'; context.strokeStyle = config.accent; context.fillRect(p.x, p.y, wall.w * cam.scale, wall.h * cam.scale); context.strokeRect(p.x, p.y, wall.w * cam.scale, wall.h * cam.scale); }); state.platforms.forEach((platform) => { const p = worldPoint(platform, cam); context.fillStyle = config.accent; context.fillRect(p.x, p.y, platform.w * cam.scale, platform.h * cam.scale); }); state.targets.forEach((target) => drawCircle(target, target.r, target.kind === 'enemy' ? '#ff697f' : target.kind === 'exit' ? '#fff18b' : config.accent, cam, 15)); state.hazards.forEach((hazard) => drawCircle(hazard, hazard.r, hazard.kind === 'shadow' ? '#39244f' : '#ff5d7d', cam, 12)); state.shots.forEach((shot) => drawCircle(shot, 7, '#fff4a6', cam, 10)); state.particles.forEach((entry) => { context.globalAlpha = Math.max(0, entry.life * 1.8); drawCircle(entry, 3, entry.color, cam); context.globalAlpha = 1; }); }
function drawPong(cam) { if (config.mode !== 'pong' || !state.ball) return; const ball = state.ball; const scale = cam.scale; context.fillStyle = config.accent; context.fillRect(cam.x + 35 * scale, cam.y + ball.playerPaddle * scale, 18 * scale, 116 * scale); context.fillRect(cam.x + 947 * scale, cam.y + ball.opponent * scale, 18 * scale, 116 * scale); drawCircle(ball, ball.r, '#fff6b0', cam, 12); }
function drawMemory(cam) { if (config.mode !== 'memory') return; const colors = [config.accent, '#ff6fb1', '#ffe673', '#8c7bff']; for (let index = 0; index < 4; index += 1) { const p = worldPoint({ x: 135 + index * 220, y: 220 }, cam); context.fillStyle = colors[index]; context.globalAlpha = state.sequence[state.sequenceIndex] === index ? .92 : .35; context.fillRect(p.x, p.y, 155 * cam.scale, 155 * cam.scale); context.globalAlpha = 1; } }
function drawRemotes(cam) { if (!state.remote) return; state.remote.players.filter((entry) => entry.id !== state.playerId).forEach((entry) => { drawCircle(entry, entry.bot ? 14 : 17, entry.bot ? '#a8adcc' : '#ffdc75', cam, entry.bot ? 0 : 10); const p = worldPoint(entry, cam); context.fillStyle = '#eef0ff'; context.font = `${Math.max(9, 12 * cam.scale)}px system-ui`; context.textAlign = 'center'; context.fillText(entry.nickname, p.x, p.y - 23 * cam.scale); }); }
function drawPlayer(cam) { const p = worldPoint(state.player, cam); context.save(); context.translate(p.x, p.y); context.rotate(state.player.facing); context.shadowBlur = 22 * cam.scale; context.shadowColor = config.accent; context.fillStyle = config.accent; context.beginPath(); context.moveTo(23 * cam.scale, 0); context.lineTo(-17 * cam.scale, 14 * cam.scale); context.lineTo(-11 * cam.scale, 0); context.lineTo(-17 * cam.scale, -14 * cam.scale); context.closePath(); context.fill(); context.restore(); }
function draw() { const cam = camera(); drawBackground(cam); drawObjects(cam); drawPong(cam); drawMemory(cam); drawRemotes(cam); drawPlayer(cam); }
function loop(now) { if (!state.started) return; const dt = Math.min(.05, (now - state.lastTime) / 1000 || 0); state.lastTime = now; updateGame(dt); draw(); requestAnimationFrame(loop); }

window.addEventListener('keydown', (event) => { if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', ' ', 'Enter'].includes(event.key)) event.preventDefault(); state.keys.add(event.key); });
window.addEventListener('keyup', (event) => state.keys.delete(event.key));
window.addEventListener('beforeunload', () => state.socket?.send(JSON.stringify({ type: 'leave' })));
actionButton.addEventListener('pointerdown', (event) => { event.preventDefault(); state.actionQueued = true; actionButton.setPointerCapture?.(event.pointerId); });
function stickMove(event) { const bounds = stick.getBoundingClientRect(); const x = clamp((event.clientX - (bounds.left + bounds.width / 2)) / (bounds.width / 2), -1, 1); const y = clamp((event.clientY - (bounds.top + bounds.height / 2)) / (bounds.height / 2), -1, 1); const length = Math.hypot(x, y) || 1; const nx = length > 1 ? x / length : x; const ny = length > 1 ? y / length : y; state.touch.x = nx; state.touch.y = ny; knob.style.transform = `translate(${nx * 36}px, ${ny * 36}px)`; }
stick.addEventListener('pointerdown', (event) => { stick.setPointerCapture(event.pointerId); stickMove(event); }); stick.addEventListener('pointermove', (event) => { if (stick.hasPointerCapture(event.pointerId)) stickMove(event); }); ['pointerup', 'pointercancel'].forEach((type) => stick.addEventListener(type, () => { state.touch.x = 0; state.touch.y = 0; knob.style.transform = ''; }));
canvas.addEventListener('pointerdown', (event) => { if (!state.started) return; const rect = canvas.getBoundingClientRect(); const cam = camera(); state.player.facing = Math.atan2((event.clientY - rect.top - cam.y) / cam.scale - state.player.y, (event.clientX - rect.left - cam.x) / cam.scale - state.player.x); state.actionQueued = true; });
