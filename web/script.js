const modal = document.querySelector('#game-modal');
const frame = document.querySelector('#game-frame');
const closeGameButtons = document.querySelectorAll('[data-close-game]');
const searchInput = document.querySelector('#game-search');
const gamesGrid = document.querySelector('#games-grid');
let gameLaunchers;
let cards;
const emptyResults = document.querySelector('#empty-results');
const toast = document.querySelector('#toast');
const authModal = document.querySelector('#auth-modal');
const authForm = document.querySelector('#auth-form');
const authGuest = document.querySelector('#auth-guest');
const authAccount = document.querySelector('#auth-account');
const accountName = document.querySelector('#account-name');
const authError = document.querySelector('#auth-error');
const confirmWrap = document.querySelector('#auth-confirm-wrap');
const authSubmit = document.querySelector('#auth-submit');
const authTitle = document.querySelector('#auth-title');
const fullscreenGameButton = document.querySelector('#game-fullscreen');
const authIntro = document.querySelector('#auth-intro');
const hostModal = document.querySelector('#host-modal');
const hostCreateForm = document.querySelector('#host-create-form');
const hostJoinForm = document.querySelector('#host-join-form');
const inviteResult = document.querySelector('#invite-result');
const inviteCode = document.querySelector('#invite-code');
const inviteLink = document.querySelector('#invite-link');
const gameDetails = {
  ship: { title: 'Ship.io', url: '/games/ship.io/client/index.html' },
  slither: { title: 'Slither.io', url: '/games/slither.io/client/index.html' },
  // This is the exported project from ~/Documents/parkour/godot. Its own
  // MobileRuntime changes controls and rendering quality on touch devices.
  parkour: { title: 'Crono Parkour', url: '/games/parkour/client/index.html' },
  anonymous_runner: { title: 'Anonymous Runner', url: '/games/anonymous-runner/client/index.html' },
};
const godotGames = [
  ['neon_dodge', 'Neon Dodge', 'Arcade · Dodge', '✦', '#6effd6'],
  ['meteor_dash', 'Meteor Dash', 'Racing · Dodge', '☄', '#ffbd55'],
  ['orbital_hoops', 'Orbital Hoops', 'Arcade · Collect', '◎', '#70e7ff'],
  ['pixel_raiders', 'Pixel Raiders', 'Action · Shooter', '▦', '#f4ff65'],
  ['maze_rush', 'Maze Rush', 'Puzzle · Maze', '⌘', '#ab86ff'],
  ['drift_nova', 'Drift Nova', 'Racing · Drift', '◒', '#ff75ce'],
  ['turbo_towers', 'Turbo Towers', 'Platform · Jump', '▥', '#ffc764'],
  ['echo_jump', 'Echo Jump', 'Platform · Bounce', '↟', '#71fff3'],
  ['bubble_blitz', 'Bubble Blitz', 'Arcade · Pop', '○', '#78e4ff'],
  ['circuit_sprint', 'Circuit Sprint', 'Racing · Sprint', '⌁', '#b0ff62'],
  ['crystal_catch', 'Crystal Catch', 'Arcade · Catch', '◆', '#7df8ff'],
  ['lava_hop', 'Lava Hop', 'Platform · Hop', '▲', '#ffad5f'],
  ['star_slinger', 'Star Slinger', 'Action · Aim', '✷', '#ffe168'],
  ['shadow_chase', 'Shadow Chase', 'Arcade · Escape', '◐', '#b88bff'],
  ['skyline_run', 'Skyline Run', 'Runner · Arcade', '▰', '#6dffbb'],
  ['void_survivor', 'Void Survivor', 'Survival · Arena', '✹', '#ff77f3'],
  ['rocket_rally', 'Rocket Rally', 'Racing · Rally', '➤', '#ff9b55'],
  ['prism_puzzle', 'Prism Puzzle', 'Puzzle · Memory', '◈', '#8fffe2'],
  ['cosmo_pong', 'Cosmo Pong', 'Classic · Pong', '◯', '#77e7ff'],
  ['drone_arena', 'Drone Arena', 'Action · Arena', '⬡', '#ffed72'],
];

function installGodotLibrary() {
  godotGames.forEach(([id, title, genre, icon, color]) => {
    // Every entry is its own Godot project and exports its own PCK package.
    // The WebGL runtime is intentionally shared once under games/godot-web-runtime.
    gameDetails[id] = { title, url: `/games/${id.replaceAll('_', '-')}/client/index.html` };
    gamesGrid.insertAdjacentHTML('beforeend', `
      <article class="game-card game-card--godot" data-game="${title.toLowerCase()} ${genre.toLowerCase()} godot webgl mobile" style="--arcade-accent: ${color}">
        <div class="game-visual arcade-visual" aria-hidden="true"><span>${icon}</span><i></i><b></b></div>
        <div class="game-card-body">
          <div><span class="tag">GODOT WEBGL</span><h3>${title}</h3><p>${genre}</p></div>
          <button class="round-play launch-game" type="button" data-game-id="${id}" aria-label="Gioca a ${title}">▶</button>
        </div>
      </article>`);
  });
  ['#host-game', '#join-game'].forEach((selector) => {
    const select = document.querySelector(selector);
    const group = document.createElement('optgroup');
    group.label = 'Godot Arcade — 20 giochi indipendenti';
    godotGames.forEach(([id, title]) => group.append(new Option(title, id)));
    select.append(group);
  });
  gameLaunchers = document.querySelectorAll('.launch-game');
  cards = [...document.querySelectorAll('[data-game]')];
}
installGodotLibrary();
let lastFocusedElement;
let toastTimer;
let authMode = 'login';
let account = null;

function localBaseUrl() {
  if (!location.protocol.startsWith('http')) return 'http://localhost:3001';
  // A project GitHub Pages site lives below /<repository>/; retain that prefix.
  const webPath = '/web/';
  const webPosition = location.pathname.indexOf(webPath);
  const basePath = webPosition >= 0 ? location.pathname.slice(0, webPosition) : '';
  return `${location.origin}${basePath}`;
}

function hasAccountBackend() {
  return isLocalNetworkHost();
}

function isLocalNetworkHost() {
  const host = location.hostname;
  return host === 'localhost' || /^127\./.test(host) || /^10\./.test(host) || /^192\.168\./.test(host) || /^172\.(1[6-9]|2\d|3[0-1])\./.test(host) || host.endsWith('.local');
}

function isTouchDevice() {
  return matchMedia('(pointer: coarse)').matches || navigator.maxTouchPoints > 0;
}

function clientForDevice(game) {
  if (game.mobileUrl && isTouchDevice()) {
    return { title: game.mobileTitle || game.title, url: game.mobileUrl };
  }
  return { title: game.title, url: game.url };
}

function launchGame(gameId, roomCode = '', shouldAutoFullscreen = true) {
  const game = gameDetails[gameId];
  if (!game) return;
  const client = clientForDevice(game);
  lastFocusedElement = document.activeElement;
  document.querySelector('#modal-title').textContent = client.title;
  frame.title = client.title;
  modal.hidden = false;
  document.body.style.overflow = 'hidden';
  const room = roomCode.trim().toUpperCase().replace(/[^A-Z2-9]/g, '').slice(0, 8);
  const separator = client.url.includes('?') ? '&' : '?';
  frame.src = `${localBaseUrl()}${client.url}${room ? `${separator}room=${encodeURIComponent(room)}` : ''}`;
  fullscreenGameButton.focus();
  if (shouldAutoFullscreen && isTouchDevice()) requestGameFullscreen();
}

function openGame(event) {
  launchGame(event.currentTarget.dataset.gameId);
}

function closeGame() {
  if (document.fullscreenElement) document.exitFullscreen?.();
  modal.hidden = true;
  document.body.style.overflow = '';
  frame.src = '';
  lastFocusedElement?.focus();
}

async function requestGameFullscreen() {
  const panel = document.querySelector('.modal-panel');
  try {
    if (!document.fullscreenElement && panel.requestFullscreen) {
      await panel.requestFullscreen();
    } else if (!document.fullscreenElement && panel.webkitRequestFullscreen) {
      panel.webkitRequestFullscreen();
    }
  } catch {
    showToast('Il browser non consente lo schermo intero in questo momento.');
  }
}

async function toggleGameFullscreen() {
  if (document.fullscreenElement) await document.exitFullscreen?.();
  else await requestGameFullscreen();
}

function updateFullscreenButton() {
  const active = Boolean(document.fullscreenElement);
  fullscreenGameButton.textContent = active ? '⤢' : '⛶';
  fullscreenGameButton.title = active ? 'Esci dallo schermo intero' : 'Schermo intero';
  fullscreenGameButton.setAttribute('aria-label', fullscreenGameButton.title);
}

function showToast(message) {
  clearTimeout(toastTimer);
  toast.textContent = message;
  toast.classList.add('show');
  toastTimer = setTimeout(() => toast.classList.remove('show'), 3600);
}

function setAccount(nextAccount) {
  account = nextAccount;
  authGuest.hidden = Boolean(account);
  authAccount.hidden = !account;
  if (account) {
    accountName.textContent = account.username;
    localStorage.setItem('cronogames_account', JSON.stringify(account));
  } else {
    localStorage.removeItem('cronogames_account');
  }
}

async function api(path, options = {}) {
  const response = await fetch(`${localBaseUrl()}${path}`, {
    credentials: 'same-origin',
    headers: { 'content-type': 'application/json', ...(options.headers || {}) },
    ...options,
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error || 'Operazione non riuscita.');
  return body;
}

function setAuthMode(mode) {
  authMode = mode;
  const registering = mode === 'register';
  document.querySelectorAll('[data-auth-mode]').forEach((button) => {
    const active = button.dataset.authMode === mode;
    button.classList.toggle('active', active);
    button.setAttribute('aria-selected', String(active));
  });
  authTitle.textContent = registering ? 'Crea il tuo account.' : 'Bentornato, pilota.';
  authIntro.textContent = registering ? 'Scegli il tuo identificativo CronoGames: lo ritroverai nei giochi e nelle classifiche.' : 'Accedi per conservare il tuo nickname e prepararti alle classifiche online.';
  confirmWrap.hidden = !registering;
  document.querySelector('#auth-confirm').required = registering;
  document.querySelector('#auth-password').autocomplete = registering ? 'new-password' : 'current-password';
  authSubmit.innerHTML = `${registering ? 'Crea account' : 'Accedi'} <span>→</span>`;
  authError.textContent = '';
}

function openAuth(mode) {
  if (!hasAccountBackend()) {
    showToast('Gli account richiedono il backend CronoGames. Su Pages puoi giocare come ospite.');
    return;
  }
  lastFocusedElement = document.activeElement;
  setAuthMode(mode);
  authForm.reset();
  authModal.hidden = false;
  document.body.style.overflow = 'hidden';
  document.querySelector('#auth-username').focus();
}

function closeAuth() {
  authModal.hidden = true;
  document.body.style.overflow = '';
  lastFocusedElement?.focus();
}

function setHostMode(mode) {
  const creating = mode === 'create';
  document.querySelectorAll('[data-host-mode]').forEach((button) => {
    const active = button.dataset.hostMode === mode;
    button.classList.toggle('active', active);
    button.setAttribute('aria-selected', String(active));
  });
  hostCreateForm.hidden = !creating;
  hostJoinForm.hidden = creating;
  inviteResult.hidden = true;
}

function openHost() {
  if (!isLocalNetworkHost()) {
    showToast('Per ospitare, apri CronoGames dal Mac host tramite il link LAN mostrato da start-local-server.command.');
    return;
  }
  lastFocusedElement = document.activeElement;
  setHostMode('create');
  hostModal.hidden = false;
  document.body.style.overflow = 'hidden';
  document.querySelector('#host-code').focus();
}

function closeHost() {
  hostModal.hidden = true;
  document.body.style.overflow = '';
  lastFocusedElement?.focus();
}

function normalizedRoomCode(value) {
  return value.trim().toUpperCase().replace(/[^A-Z2-9]/g, '').slice(0, 8);
}

gameLaunchers.forEach((button) => button.addEventListener('click', openGame));
closeGameButtons.forEach((button) => button.addEventListener('click', closeGame));
fullscreenGameButton.addEventListener('click', toggleGameFullscreen);
document.addEventListener('fullscreenchange', updateFullscreenButton);
document.querySelectorAll('[data-open-auth]').forEach((button) => button.addEventListener('click', () => openAuth(button.dataset.openAuth)));
document.querySelectorAll('[data-close-auth]').forEach((button) => button.addEventListener('click', closeAuth));
document.querySelectorAll('[data-auth-mode]').forEach((button) => button.addEventListener('click', () => setAuthMode(button.dataset.authMode)));
document.querySelectorAll('[data-open-host]').forEach((button) => button.addEventListener('click', openHost));
document.querySelectorAll('[data-close-host]').forEach((button) => button.addEventListener('click', closeHost));
document.querySelectorAll('[data-host-mode]').forEach((button) => button.addEventListener('click', () => setHostMode(button.dataset.hostMode)));
document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') return;
  if (!modal.hidden) closeGame();
  if (!authModal.hidden) closeAuth();
  if (!hostModal.hidden) closeHost();
});

authForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const username = document.querySelector('#auth-username').value.trim();
  const password = document.querySelector('#auth-password').value;
  const confirm = document.querySelector('#auth-confirm').value;
  if (authMode === 'register' && password !== confirm) {
    authError.textContent = 'Le password non coincidono.';
    return;
  }
  authError.textContent = '';
  authSubmit.disabled = true;
  authSubmit.textContent = 'Attendi…';
  try {
    const result = await api(`/api/auth/${authMode === 'register' ? 'register' : 'login'}`, { method: 'POST', body: JSON.stringify({ username, password }) });
    setAccount(result.account);
    closeAuth();
    showToast(`Benvenuto, ${result.account.username}.`);
  } catch (error) {
    authError.textContent = error.message;
  } finally {
    authSubmit.disabled = false;
    authSubmit.innerHTML = `${authMode === 'register' ? 'Crea account' : 'Accedi'} <span>→</span>`;
  }
});

document.querySelector('#logout-button').addEventListener('click', async () => {
  try { await api('/api/auth/logout', { method: 'POST', body: '{}' }); } catch { /* The local UI can still be cleared. */ }
  setAccount(null);
  showToast('Sessione terminata.');
});

hostCreateForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const submit = hostCreateForm.querySelector('button[type="submit"]');
  submit.disabled = true;
  try {
    const result = await api('/api/rooms/create', { method: 'POST', body: JSON.stringify({ game: document.querySelector('#host-game').value, code: normalizedRoomCode(document.querySelector('#host-code').value) }) });
    inviteCode.textContent = result.code;
    inviteLink.value = result.inviteUrl;
    inviteResult.hidden = false;
    showToast(`Server pronto: codice ${result.code}.`);
  } catch (error) {
    showToast(error.message);
  } finally {
    submit.disabled = false;
  }
});

hostJoinForm.addEventListener('submit', (event) => {
  event.preventDefault();
  const code = normalizedRoomCode(document.querySelector('#join-code').value);
  if (code.length < 5) return showToast('Inserisci un codice stanza valido.');
  closeHost();
  launchGame(document.querySelector('#join-game').value, code);
});

document.querySelector('#copy-invite').addEventListener('click', async () => {
  try {
    await navigator.clipboard.writeText(inviteLink.value);
    showToast('Link di invito copiato.');
  } catch {
    inviteLink.select();
    document.execCommand('copy');
    showToast('Link selezionato: copialo e invialo agli amici.');
  }
});

searchInput.addEventListener('input', ({ target }) => {
  const query = target.value.trim().toLocaleLowerCase('it');
  const visible = cards.filter((card) => {
    const matches = card.dataset.game.includes(query);
    card.hidden = !matches;
    return matches;
  });
  emptyResults.hidden = visible.length > 0;
});

document.querySelectorAll('[data-message]').forEach((button) => button.addEventListener('click', () => showToast(button.dataset.message)));
if (hasAccountBackend()) {
  api('/api/auth/me').then(({ account: currentAccount }) => setAccount(currentAccount)).catch(() => setAccount(null));
} else {
  setAccount(null);
}

const inviteParams = new URLSearchParams(location.search);
const inviteGame = inviteParams.get('game');
const inviteRoom = normalizedRoomCode(inviteParams.get('room') || '');
if (inviteGame && inviteRoom.length >= 5 && gameDetails[inviteGame]) {
  window.setTimeout(() => launchGame(inviteGame, inviteRoom, false), 80);
}
