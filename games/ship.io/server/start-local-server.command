#!/bin/zsh
set -eu

SERVER_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SERVER_DIR"

if [ ! -d node_modules ]; then
  npm install
fi

echo "Avvio CronoGames sulla rete locale…"
echo "Lascia aperta questa finestra mentre giocate."
HOST=0.0.0.0 PORT=3001 npm start
