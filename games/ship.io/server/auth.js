const crypto = require('crypto');
const fs = require('fs/promises');
const path = require('path');
const { promisify } = require('util');

const scrypt = promisify(crypto.scrypt);
const DATA_DIRECTORY = process.env.CRONOGAMES_DATA_DIR || path.join(__dirname, 'data');
const ACCOUNTS_FILE = path.join(DATA_DIRECTORY, 'accounts.json');
const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 7;
const sessions = new Map();
let writeQueue = Promise.resolve();

function publicAccount(account) {
  return { id: account.id, username: account.username, createdAt: account.createdAt };
}

async function readDatabase() {
  await fs.mkdir(DATA_DIRECTORY, { recursive: true });
  try {
    return JSON.parse(await fs.readFile(ACCOUNTS_FILE, 'utf8'));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    const initial = { accounts: [] };
    await fs.writeFile(ACCOUNTS_FILE, JSON.stringify(initial, null, 2), { mode: 0o600 });
    return initial;
  }
}

async function updateDatabase(mutator) {
  const operation = writeQueue.then(async () => {
    const database = await readDatabase();
    const result = await mutator(database);
    await fs.writeFile(ACCOUNTS_FILE, JSON.stringify(database, null, 2), { mode: 0o600 });
    return result;
  });
  writeQueue = operation.catch(() => undefined);
  return operation;
}

function validateCredentials(username, password) {
  const normalizedUsername = String(username || '').trim().toLowerCase();
  if (!/^[a-z0-9_]{3,16}$/.test(normalizedUsername)) {
    throw new Error('Il nome utente deve avere 3–16 caratteri: lettere, numeri o _.');
  }
  if (typeof password !== 'string' || password.length < 8 || password.length > 128) {
    throw new Error('La password deve contenere almeno 8 caratteri.');
  }
  return normalizedUsername;
}

async function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const derivedKey = await scrypt(password, salt, 64);
  return `${salt}:${derivedKey.toString('hex')}`;
}

async function passwordMatches(password, storedHash) {
  const [salt, expected] = String(storedHash).split(':');
  if (!salt || !expected) return false;
  const actual = await hashPassword(password, salt);
  return crypto.timingSafeEqual(Buffer.from(actual), Buffer.from(`${salt}:${expected}`));
}

async function register(username, password) {
  const normalizedUsername = validateCredentials(username, password);
  return updateDatabase(async (database) => {
    if (database.accounts.some((account) => account.username === normalizedUsername)) {
      throw new Error('Questo nome utente è già in uso.');
    }
    const account = {
      id: crypto.randomUUID(),
      username: normalizedUsername,
      passwordHash: await hashPassword(password),
      createdAt: new Date().toISOString(),
    };
    database.accounts.push(account);
    return publicAccount(account);
  });
}

async function login(username, password) {
  const normalizedUsername = String(username || '').trim().toLowerCase();
  if (!normalizedUsername || typeof password !== 'string') return null;
  const database = await readDatabase();
  const account = database.accounts.find((entry) => entry.username === normalizedUsername);
  if (!account || !(await passwordMatches(password, account.passwordHash))) return null;
  return publicAccount(account);
}

function createSession(accountId) {
  const token = crypto.randomBytes(32).toString('base64url');
  sessions.set(token, { accountId, expiresAt: Date.now() + SESSION_TTL_MS });
  return token;
}

async function accountFromSession(token) {
  const session = sessions.get(token);
  if (!session || session.expiresAt < Date.now()) {
    sessions.delete(token);
    return null;
  }
  const database = await readDatabase();
  const account = database.accounts.find((entry) => entry.id === session.accountId);
  return account ? publicAccount(account) : null;
}

function removeSession(token) {
  if (token) sessions.delete(token);
}

function readCookie(header, name) {
  const cookie = String(header || '').split(';').map((part) => part.trim()).find((part) => part.startsWith(`${name}=`));
  return cookie ? decodeURIComponent(cookie.slice(name.length + 1)) : null;
}

function sessionCookie(token) {
  return `cg_session=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${SESSION_TTL_MS / 1000}`;
}

function expiredSessionCookie() {
  return 'cg_session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0';
}

module.exports = { accountFromSession, createSession, expiredSessionCookie, login, readCookie, register, removeSession, sessionCookie };
