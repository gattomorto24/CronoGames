# Server locale per amici

1. Collega tutti alla stessa rete Wi-Fi.
2. Fai doppio clic su `start-local-server.command` nel Finder.
3. Se macOS chiede il permesso di rete per Node, consenti le connessioni in entrata.
4. Nel Terminale apparirà un indirizzo simile a `http://192.168.1.42:3001/web/index.html`.
5. Apri quell'indirizzo sul Mac host, premi **Apri server**, scegli il gioco e genera un codice stanza.
6. Invia agli amici il link di invito o il codice: il portale e i giochi useranno automaticamente il WebSocket del Mac che ospita la partita.

Il server è pensato per la LAN. Per amici fuori casa occorre un server pubblico HTTPS/WSS oppure una VPN mesh come Tailscale: non esporre la porta 3001 su Internet senza autenticazione, HTTPS e firewall adeguati.
