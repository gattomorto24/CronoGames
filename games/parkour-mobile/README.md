# Crono Parkour Mobile

Questo è un gioco Godot indipendente da `games/parkour/godot`: non contiene il livello desktop, il personaggio Mixamo, lo state machine da tastiera/mouse o gli asset pesanti.

- `godot/`: sorgente mobile con percorso low-poly, fisica semplificata, checkpoint, nuclei da raccogliere, telecamera third-person fissa, joystick e tasti touch.
- `client/`: export WebGL usato automaticamente dal portale su un dispositivo touch.

Il client condivide soltanto il runtime Web di Godot già presente in `games/parkour/client/`; il suo PCK contiene solo la versione mobile. Questo evita di duplicare il runtime e impedisce al telefono di caricare i 34 MB di contenuti del livello PC.

Per rigenerare l'export:

```bash
cd ~/Documents/CronoGames
godot --headless --path games/parkour-mobile/godot --export-release Web ../client/index.html
```

Dopo un export, `client/index.html` deve mantenere `mainPack: "index.pck"` e il runtime condiviso `../../parkour/client/index`; non copiare i file `index.wasm` e `index.js` nella cartella mobile.
