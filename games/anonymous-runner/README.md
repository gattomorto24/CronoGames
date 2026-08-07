# Anonymous Runner

Questo è un gioco Godot indipendente da Crono Parkour: un runner arcade leggero, disponibile sia da PC sia da mobile.

- `godot/`: sorgente con percorso low-poly, fisica semplificata, checkpoint, nuclei da raccogliere, telecamera third-person fissa, joystick/tasti touch e fallback tastiera per PC.
- `client/`: export WebGL pubblicato dal portale.

Il client condivide soltanto il runtime Web di Godot già presente in `games/parkour/client/`; il suo PCK contiene solo la versione mobile. Questo evita di duplicare il runtime e impedisce al telefono di caricare i 34 MB di contenuti del livello PC.

Per rigenerare l'export:

```bash
cd ~/Documents/CronoGames
godot --headless --path games/anonymous-runner/godot --export-release Web ../client/index.html
```

Dopo un export, `client/index.html` deve mantenere `mainPack: "index.pck"` e il runtime condiviso `../../parkour/client/index`; non copiare i file `index.wasm` e `index.js` nella cartella mobile.
