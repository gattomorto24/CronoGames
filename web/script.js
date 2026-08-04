const modal = document.querySelector('#game-modal');
const frame = document.querySelector('#game-frame');
const gameLaunchers = document.querySelectorAll('.launch-game');
const closeGameButtons = document.querySelectorAll('[data-close-game]');
const searchInput = document.querySelector('#game-search');
const cards = [...document.querySelectorAll('[data-game]')];
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
const authIntro = document.querySelector('#auth-intro');
const gameDetails = {
  ship: { title: 'Ship.io', url: '/games/ship.io/client/index.html' },
  slither: { title: 'Slither.io', url: '/games/slither.io/client/index.html' },
};
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
  return location.hostname === 'localhost' || location.hostname === '127.0.0.1';
}

function openGame(event) {
  const game = gameDetails[event.currentTarget.dataset.gameId];
  if (!game) return;
  lastFocusedElement = document.activeElement;
  document.querySelector('#modal-title').textContent = game.title;
  frame.title = game.title;
  modal.hidden = false;
  document.body.style.overflow = 'hidden';
  frame.src = `${localBaseUrl()}${game.url}`;
  document.querySelector('.modal-close').focus();
}

function closeGame() {
  modal.hidden = true;
  document.body.style.overflow = '';
  frame.src = '';
  lastFocusedElement?.focus();
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

gameLaunchers.forEach((button) => button.addEventListener('click', openGame));
closeGameButtons.forEach((button) => button.addEventListener('click', closeGame));
document.querySelectorAll('[data-open-auth]').forEach((button) => button.addEventListener('click', () => openAuth(button.dataset.openAuth)));
document.querySelectorAll('[data-close-auth]').forEach((button) => button.addEventListener('click', closeAuth));
document.querySelectorAll('[data-auth-mode]').forEach((button) => button.addEventListener('click', () => setAuthMode(button.dataset.authMode)));
document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') return;
  if (!modal.hidden) closeGame();
  if (!authModal.hidden) closeAuth();
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
