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
4. Apri **Ship.io**, **Slither.io** o **Crono Parkour** dalla libreria. Su `localhost` i giochi si connettono automaticamente alla stanza multiplayer.

## Struttura

- `web/`: landing page CronoGames responsive.
- `games/ship.io/godot/`: progetto sorgente Godot 4 (scene e GDScript).
- `games/ship.io/client/`: export WebGL/HTML5 prodotto da Godot.
- `games/slither.io/godot/`: progetto sorgente Godot 4 per Slither.io.
- `games/slither.io/client/`: export WebGL/HTML5 di Slither.io.
- `games/parkour/godot/`: sorgente Godot 4 di Crono Parkour, configurato per WebGL (GL Compatibility).
- `games/parkour/client/`: export WebGL/HTML5 di Crono Parkour.
- `games/ship.io/server/`: static hosting, WebSocket e API account locale.

## Stanze multiplayer e bot

Il WebSocket locale gestisce stanze separate per `ship`, `slither` e `parkour`: ogni stanza accoglie fino a 20 giocatori reali e riempie automaticamente gli slot liberi con bot. Il server invia periodicamente posizioni, rotazione, stato e Top 5.

Per un deploy pubblico, GitHub Pages ospita soltanto i file WebGL: è necessario pubblicare anche questo server su un host Node.js con HTTPS/WSS. I client possono puntare al server pubblico aggiungendo `?ws=wss://tuo-dominio.example` all'URL del gioco.

## Account locale

L'account viene creato tramite `POST /api/auth/register`, con password hash `scrypt`, sessione in cookie `HttpOnly` e profilo tramite `GET /api/auth/me`. I dati locali sono creati al primo account in `games/ship.io/server/data/accounts.json` e sono esclusi dal versionamento.

Prima di pubblicare il progetto serviranno HTTPS, un database gestito, rate limiting, reset password e verifica email: questa implementazione è una base locale per lo sviluppo.

Il portale usa asset CSS temporanei; inserisci le immagini di riferimento in `web/assets/images/` per la rifinitura grafica.
