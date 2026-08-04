# CronoGames

## Avvio locale

1. In un terminale, avvia il server multiplayer e lo static hosting locale:

   ```bash
   cd ~/Documents/CronoGames/games/ship.io/server
   npm install
   npm start
   ```

2. Apri [http://localhost:3001/web/index.html](http://localhost:3001/web/index.html) nel browser.
3. Crea un account dal pulsante **Registrati**, oppure gioca come ospite.
4. Apri **Ship.io** o **Slither.io** dalla libreria.

## Struttura

- `web/`: landing page CronoGames responsive.
- `games/ship.io/godot/`: progetto sorgente Godot 4 (scene e GDScript).
- `games/ship.io/client/`: export WebGL/HTML5 prodotto da Godot.
- `games/slither.io/godot/`: progetto sorgente Godot 4 per Slither.io.
- `games/slither.io/client/`: export WebGL/HTML5 di Slither.io.
- `games/ship.io/server/`: static hosting, WebSocket e API account locale.

## Account locale

L'account viene creato tramite `POST /api/auth/register`, con password hash `scrypt`, sessione in cookie `HttpOnly` e profilo tramite `GET /api/auth/me`. I dati locali sono creati al primo account in `games/ship.io/server/data/accounts.json` e sono esclusi dal versionamento.

Prima di pubblicare il progetto serviranno HTTPS, un database gestito, rate limiting, reset password e verifica email: questa implementazione è una base locale per lo sviluppo.

Il portale usa asset CSS temporanei; inserisci le immagini di riferimento in `web/assets/images/` per la rifinitura grafica.
