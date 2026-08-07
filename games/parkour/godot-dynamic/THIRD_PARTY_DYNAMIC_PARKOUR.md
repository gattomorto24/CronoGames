# Dynamic Parkour System — attribuzione

Il personaggio Erika, le texture, le animazioni e il comportamento di riferimento
provengono dalla copia locale del progetto **Dynamic Parkour System** creata
dall'utente in:

`../Dynamic Parkour System/Assets/Dynamic Parkour System/`

Autore originale: Èric Canela  
Copyright © 2023 Èric Canela

Il progetto originale è distribuito con licenza MIT. Una copia integrale della
licenza è conservata in:

`assets/dynamic_parkour/LICENSE`

## Adattamento

Il codice originale è scritto per Unity/C#. Per usarlo nella città Godot non è
stato incorporato un secondo runtime: sensori, priorità delle azioni,
movimento MatchTarget e macchina a stati sono stati portati in GDScript,
mantenendo i parametri originali rilevanti.

Sono incluse senza conversione artistica:

- la mesh scheletrica Erika;
- le texture del personaggio;
- le 35 clip FBX usate dal controller;
- la gerarchia a 67 ossa condivisa da modello e animazioni.

Le animazioni mantengono il movimento verticale del bacino; la componente
orizzontale del root motion viene rimossa durante la costruzione della libreria
Godot perché posizione finale, collisioni e correzione di atterraggio sono
gestite dalla macchina a stati.
