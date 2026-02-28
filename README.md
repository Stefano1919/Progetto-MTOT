# Progetto-MTOT

Elaborato progettuale di Metodi e Tecniche per l'Osservazione della Terra (a.a. 2025/2026).

Il progetto consiste nell'analizzare un dataset di misurazioni IASI e di applicare tecniche di riduzione della dimensionalità per estrarre informazioni utili, focalizzandosi sul processo di ricostruzione dei dati e sulla valutazione della bontà della ricostruzione attraverso tecniche di compressione e decompressione dei dati con l'impiego della PCA.

## Struttura del Progetto

```
Progetto-MTOT/
├── build_base.m              # Funzione principale: PCA, ricostruzione e grafici
├── calcola_bonus.m           # Analisi bonus: dev. std. delle PC scartate vs rumore
├── resources/
│   ├── IASI.mat              # Dataset IASI (da scaricare separatamente)
│   └── nednL1C.txt           # Rumore strumentale di riferimento
├── gui/
│   ├── entrypoint.m          # Punto di ingresso della GUI
│   ├── App.m                 # Classe applicazione (finestra principale)
│   ├── Controller.m          # Controller globale della GUI
│   ├── Model.m               # Modello dati della GUI
│   ├── DynamicTab.m          # Generazione dinamica dei tab
│   ├── TabController.m       # Controller dei singoli tab
│   ├── PlotView.m            # Visualizzazione dei grafici nei tab
│   ├── ResultTab.m           # Tab dei risultati
│   ├── Component.m           # Classe base per i componenti UI
│   ├── config/
│   │   ├── config.yaml       # Configurazione esercizi, parametri e pipeline
│   │   └── spectral_analysis/
│   │       ├── pipeline.yaml     # Pipeline di esecuzione dell'analisi
│   │       └── tabSettings.yaml  # Definizione dei controlli UI
│   ├── utility/
│   │   ├── YamlParser.m      # Parser YAML per la configurazione
│   │   └── tableToHtml.m     # Conversione tabelle in HTML
│   └── assets/
│       └── IASI.jpg          # Immagine decorativa per la GUI
└── extra_scripts/            # Script legacy (versioni precedenti)
    ├── build_base2.m
    ├── build_base3.m
    └── bonus.m
```

## Preparazione

Per prima cosa, è necessario recuperare il file `.mat` contenente le misurazioni IASI, disponibile [qui](https://drive.google.com/file/d/18QAiLqiDqX90F_WEhJIL4U-EnSKDdvMa/view?usp=sharing) per il download. Una volta scaricato, è necessario spostarlo nella cartella `resources` del progetto e rinominarlo in `IASI.mat`.

## Esecuzione

### 1. Esecuzione da riga di comando (CLI)

Aprire MATLAB e impostare la directory corrente sulla cartella radice del progetto.

**Analisi spettrale (Task 1, 2, 3):**

```matlab
% Parametri obbligatori:
%   bande_input           – Vettore degli estremi delle bande (es. [645, 800, 980]) oppure vettore con bande esplicitamente definite (es. [645, 800; 800, 980; 980, 1080])
%   terreno_selezionato   – Tipo di terreno: 'Terra' oppure 'Mare'
%   fov_selezionato       – Field of View: intero da 1 a 120
%   nubi_max              – Soglia massima di nuvolosità (0–100, in %)
%
% Parametro facoltativo:
%   nomi_bande            – Cell array con i nomi delle bande (auto-generati se omesso)

risultati = build_base([645, 800; 800, 980; 980, 1080], 'Terra', 1, 10);
```

**Analisi bonus (Task 4):**

La funzione `calcola_bonus` viene invocata automaticamente da `build_base` per ogni banda. I risultati (rapporto e deviazione standard) sono inclusi nella struttura restituita:

```matlab
risultati{1}.rapporto_bonus
risultati{1}.dev_std_bonus
```

### 2. Esecuzione tramite interfaccia grafica (GUI)

1. Aprire MATLAB e navigare nella cartella `gui/` del progetto.
2. Aprire ed eseguire lo script `entrypoint.m` (pulsante **Run** nella barra degli strumenti). Quando richiesto, cambiare la directory corrente come suggerito da MATLAB (non aggiungere la cartella ai path).
3. Si aprirà la finestra principale della GUI con un pannello di parametri dove è possibile configurare:
   - **Bande Spettrali** – estremi delle bande (separati da virgola)
   - **Field of View** – valore numerico (1–120)
   - **Tipo di Terreno** – *Terra* o *Mare*
   - **Nuvolosità Massima** – percentuale (0–100 %)
4. Premere il pulsante di esecuzione ('Simula'): i grafici verranno generati e visualizzati direttamente nei tab della GUI.