# Crono Arcade Library

Questa singola applicazione Canvas ospita 20 mini-giochi con regole, palette e controlli dedicati. Ogni URL riceve `?game=<id>` e, facoltativamente, `&room=<codice>`.

Su GitHub Pages i giochi funzionano in modalità solo. Dal server locale CronoGames (`games/ship.io/server/server.js`) diventano multiplayer leggero: posizioni, bot, presenze e top 5 sono sincronizzati tramite WebSocket. Il portale crea e condivide i codici stanza.
