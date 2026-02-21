# Progetto-MTOT

Elaborato progettuale di Metodi e Tecniche per l'Osservazione della Terra (a.a. 2025/2026).

Il progetto consiste nell'analizzare un dataset di misurazioni IASI e di applicare tecniche di riduzione della dimensionalità per estrarre informazioni utili, focalizzandosi sul processo di ricostruzione dei dati e sulla valutazione della bontà della ricostruzione attraverso tecniche di compressione e decompressione dei dati con l'impiego della PCA.

## Preparazione

Per prima cosa, è necessario recuperare il file `.mat` contenente le misurazioni IASI, disponibile [qui](https://drive.google.com/file/d/18QAiLqiDqX90F_WEhJIL4U-EnSKDdvMa/view?usp=sharing) per il download. Una volta scaricato, è necessario spostarlo nella cartella `resources` del progetto.

## Esecuzione

Per poter eseguire il codice è possibile seguire due diverse strategie:

### 1. Esecuzione in forma di script

È possibile eseguire il codice aprendo MATLAB e digitando `build_base2` nel prompt dei comandi, per eseguire lo script che risolve il problema relativo ai task 1,2 e 3 del progetto, oppure `bonus` nel prompt dei comandi per eseguire lo script che risolve il problema relativo al task 4 del progetto.

### 2. Esecuzione tramite interfaccia grafica

Il modo più semplice per eseguire la GUI è selezionare lo script `gui/entrypoint.m` premendo il tasto "Run" nella barra degli strumenti di MATLAB. Quando richiesto, cambiare la directory corrente come suggerito (e non aggiungere la cartella ai path di MATLAB).
Successivamente, si aprirà la finestra principale della GUI, da cui è possibile navigare tra le varie funzionalità del progetto.