# Crono Parkour — versione Godot

> Sorgente completo pubblicato con CronoGames. L'export browser usato dal
> portale è in `../client`; questa è la versione modificabile del gioco reale
> proveniente da `Documenti/parkour`.

Questa cartella contiene la versione principale del gioco. Godot 4 gestisce
scena, rendering, fisica, modello scheletrico e animazioni; la GDExtension C++
costruisce il quartiere, prepara le collisioni e collega il controller alla
scena Crono.

Il personaggio e il motore attivi sono il port del progetto Unity
**Dynamic Parkour System**. `DynamicParkour/DynamicParkourPlayer.tscn` usa
Erika, il suo scheletro originale e 35 clip di movimento importate dal progetto
sorgente.

Il port conserva i parametri e il comportamento essenziale del sistema:

- camminata a 3 m/s e corsa a 4,5 m/s relative alla telecamera;
- scivolata contestuale di 4 m con capsula abbassata;
- rilevamento a sette raggi per pareti e sporgenze;
- selezione automatica fra vault, reach, presa, predicted jump e salto libero;
- auto-intent con anticipo proporzionale alla velocità e cono direzionale;
- salto libero orientato secondo l'intenzione `WASD`, anche durante la fase aerea;
- predicted jump fino a 5 m, con arco e atterraggio guidato;
- sospensione braced o free, shimmy, salti laterali, salto dal muro e discesa;
- scalata continua sulle facciate alte, con mani allineate al piano del muro;
- salto muro-muro con ricerca e riaggancio automatico della parete opposta;
- centratura sulla sommità anche quando il muro è più stretto della capsula;
- stato edge-balance che impedisce cadute involontarie senza bloccare il salto;
- trazione in due fasi, prima verticale e poi sopra la superficie;
- allineamento scheletrico delle mani al bordo, equivalente al MatchTarget/IK
  usato dal progetto Unity.

La città contiene ora ostacoli inseriti naturalmente fra mercato e tetti:
arcate per slide, parapetti da vault, terrazze per predicted jump, facciate con
cornici scalabili e un vicolo per i salti muro-muro. Tutti usano vere
collisioni, quindi i sensori del controller decidono l'azione in base alla
geometria circostante.

## Avvio

Il modo più semplice è aprire dalla cartella principale:

```sh
./Avvia\ Crono\ Parkour.command
```

In alternativa:

```sh
cd "/Users/antoninostrano/Documents/Crono Bridge Betas/parkour/godot"
scons platform=macos arch=arm64 target=template_debug build_profile=build_profile.json
godot --path .
```

## Web e mobile

`scenes/main.tscn` mantiene l'avvio nativo completo. `scenes/web_main.tscn`
è il bootstrap WebGL: usa gli stessi modelli, controllore e città, ma esclude
la GDExtension nativa non supportata dai browser. Il nodo `MobileRuntime`
rileva il touch, sostituisce gli input PC con levetta e pulsanti e abbassa il
costo del rendering su telefono. Gli artefatti di compilazione (`.godot/`,
`bin/`, oggetti SCons) non sono versionati perché Godot/SCons li rigenerano.

Per rigenerare il client Web dal repository, prima importa le risorse e poi
esporta il preset Web:

```sh
godot --headless --recovery-mode --path . --import
godot --headless --path . --export-release "Web" ../client/index.html
```

## Comandi

- `WASD`: movimento
- `Shift`: scatto
- `Spazio`: vault, reach, presa, predicted jump o salto libero
- `Ctrl`: scivolata in movimento; lascia la presa quando appesi
- `A`/`D` da appesi: shimmy
- `Spazio` da appesi: sale; con `A`/`D` salta lateralmente
- `Spazio` contro una parete: aggancia; poi `W` o `Spazio` continua la scalata
- `S` + `Spazio` in parete: salta e si riaggancia al muro opposto
- `R`: ritorno al punto iniziale
- `Esc`: libera o riprende il mouse

## Verifiche automatiche

```sh
godot --headless --rendering-method gl_compatibility --path . -- --dynamic-movement-test
godot --headless --rendering-method gl_compatibility --path . -- --dynamic-jump-test
godot --headless --rendering-method gl_compatibility --path . -- --dynamic-slide-test
godot --headless --rendering-method gl_compatibility --path . -- --dynamic-predicted-jump-test
godot --headless --rendering-method gl_compatibility --path . -- --dynamic-vault-test
godot --headless --rendering-method gl_compatibility --path . -- --dynamic-reach-test
godot --headless --rendering-method gl_compatibility --path . -- --dynamic-ledge-test
godot --headless --rendering-method gl_compatibility --path . -- --dynamic-wall-climb-test
godot --headless --rendering-method gl_compatibility --path . -- --dynamic-wall-to-wall-test
```

I test verificano locomozione, salto e atterraggio, slide, predicted jump,
vault, reach, presa-sospensione-trazione-salita, scalata continua e
salto-riaggancio fra pareti contrapposte.

Licenza e attribuzione del sistema importato sono riportate in
`THIRD_PARTY_DYNAMIC_PARKOUR.md`.
