close all; clear all
load IASI.mat

% ========================================================================
% DEFINIZIONE DELLA FINESTRA SPETTRALE DI INTERESSE
% ========================================================================
w1 = 2150.0;   % Primo numero d'onda della banda da analizzare [cm^-1]
w2 = 2250.0;  % Ultimo numero d'onda della banda da analizzare [cm^-1]
dw = 0.25;    % Risoluzione spettrale (passo di campionamento) di IASI [cm^-1]

% Crea il vettore completo dei numeri d'onda di IASI
% Copre l'intero range spettrale dello strumento da 645 a 2760 cm^-1
wave = [645:dw:2760]';  % Griglia spettrale completa di IASI

% ========================================================================
% ESTRAZIONE DIMENSIONI E CALCOLO INDICI
% ========================================================================
% Estrae le dimensioni della matrice delle radianze
% n1: numero di canali spettrali
% n2: numero di profili atmosferici (spettri diversi)
% n3: numero di angoli di vista (FOV - Field Of View)
%[n1,n2,n3] = size(c.R);
n3 = 1;
[n1,n2] = size(d.rad);

% Calcola l'indice del primo numero d'onda nella griglia completa
% fix() arrotonda verso zero (parte intera)
nb1 = fix(w1-wave(1))/dw+1;

% Calcola l'indice dell'ultimo numero d'onda nella griglia completa
nb2 = fix(w2-wave(1))/dw+1;

%% PARTE NUOVA FUNZIONANTE NON TOCCARE SOPRA
X_plot = d.rad(nb1:nb2, :); 

% Estrae il vettore dei numeri d'onda corrispondente (Asse X)
w_plot = wave(nb1:nb2);

% ========================================================================
% VISUALIZZAZIONE DEGLI SPETTRI
% ========================================================================
figure(1); clf; % Apre una figura e la pulisce

% ATTENZIONE: Plottare tutti gli 89.000 spettri insieme blocca il PC.
% Ne plottiamo solo i primi 50 per vedere l'andamento, oppure usiamo
% un filtro se lo hai definito prima.
numero_spettri_da_plottare = 50; 

plot(w_plot, X_plot(:, 1:numero_spettri_da_plottare));

% Abbellimento del grafico (Obbligatorio per l'esame)
title(['Spettri IASI - Banda N_2O (' num2str(w1) '-' num2str(w2) ' cm^{-1})']);
xlabel('Numero d''onda [cm^{-1}]');
ylabel('Radianza [mW / (m^2 sr cm^{-1})]');
grid on;
xlim([w1 w2])
% ========================================================================
% ESTRAZIONE DEGLI SPETTRI PER IL PRIMO FOV
% ========================================================================
% Estrae solo gli spettri relativi al primo campo di vista (FOV=1, tipicamente nadir)
% nella banda spettrale selezionata [w1, w2]
% X è una matrice (numero_canali × numero_spettri)
X(nb1:nb2,1:n2) = d.rad(nb1:nb2,1:n2,1);

% Estrae il vettore dei numeri d'onda corrispondente alla banda selezionata
w = wave(nb1:nb2);

% ========================================================================
% VISUALIZZAZIONE DEGLI SPETTRI
% ========================================================================
% Plotta tutti gli spettri nella banda selezionata
% Ogni linea rappresenta uno spettro diverso (condizione atmosferica diversa)
figure;


% ========================================================================
% CALCOLO DELLE STATISTICHE DELL'INSIEME DI SPETTRI
% ========================================================================
% Calcola lo spettro medio dell'intero dataset
% mean(X,2) calcola la media lungo le colonne (dimensione 2)
% Ogni elemento di Xm è la radianza media per quel canale spettrale
Xm  = mean(X,2);

% Calcola la deviazione standard per ogni canale spettrale
% std(X,1,2): normalizzazione per 1/N (non 1/(N-1))
% dimensione 2: calcola lungo le colonne
% Xds misura la variabilità naturale delle radianze per ogni canale
Xds = std(X,1,2);

% ========================================================================
% VISUALIZZAZIONE DELLE STATISTICHE
% ========================================================================
% Plotta lo spettro medio
% Rappresenta la radianza "tipica" osservata nella regione tropicale
figure; 
plot(w,Xm)

% Plotta la deviazione standard
% Mostra quali canali spettrali hanno maggiore variabilità
% Alta variabilità → più informazione sulla variabilità atmosferica
figure; 
plot(w,Xds)

% ========================================================================
% STANDARDIZZAZIONE DEGLI SPETTRI
% ========================================================================
% La standardizzazione è fondamentale per la PCA:
% - Rimuove il valore medio (centra i dati)
% - Normalizza per la deviazione standard (rende i canali comparabili)

% Inizializza la matrice degli spettri standardizzati
Xn = zeros(nb2-nb1+1,n2);

% Loop su tutti gli spettri
for i=1:n2
    % Standardizzazione: (valore - media) / deviazione_standard
    % Dopo questa operazione, ogni canale ha media=0 e varianza=1
    Xn(:,i) = (X(:,i)-Xm)./Xds;
end

% ========================================================================
% CALCOLO DELLA MATRICE DI COVARIANZA
% ========================================================================
% La matrice di covarianza misura come variano insieme i diversi canali spettrali
% C = (1/N) * Xn * Xn^T
% Dimensioni: (numero_canali × numero_canali)
% C(i,j) rappresenta la covarianza tra il canale i e il canale j
C = (1/n2)*(Xn*Xn');

% ========================================================================
% DECOMPOSIZIONE AI VALORI SINGOLARI (SVD) / PCA
% ========================================================================
% SVD decompone la matrice di covarianza: C = U * S * V'
% U: matrice degli autovettori (componenti principali) - direzioni di massima varianza
% S: matrice diagonale degli autovalori - varianza spiegata da ogni componente
% V: in questo caso V=U perché C è simmetrica
% Gli autovettori sono ordinati per autovalore decrescente
[U,S,V] = svd(C);

% ========================================================================
% VISUALIZZAZIONE DEGLI AUTOVALORI
% ========================================================================
% Plotta gli autovalori in scala semi-logaritmica
% Gli autovalori decrescono rapidamente: poche componenti spiegano la maggior parte della varianza
% Questo giustifica l'uso della PCA per la riduzione dimensionale
figure;
semilogy(diag(S))
title("Autovalori delle componenti principali")

% ========================================================================
% VISUALIZZAZIONE DELLE PRIME 20 COMPONENTI PRINCIPALI
% ========================================================================
% Ogni componente principale (EOF - Empirical Orthogonal Function) è uno "spettro base"
% Gli spettri reali possono essere rappresentati come combinazione lineare di queste basi
figure;
for i=1:20
    subplot(5,4,i)  % Griglia 5×4 di subplot
    plot(wave(nb1:nb2),U(:,i))
    title(["PC " num2str(i)]);
end

% ========================================================================
% RICOSTRUZIONE DI UNO SPETTRO USANDO UN NUMERO LIMITATO DI PCA
% ========================================================================
% Dimostra come si può approssimare uno spettro usando solo poche componenti principali

% Numero di componenti principali da usare nella ricostruzione
tau = 10;

% Seleziona un esempio: il 100-esimo spettro del dataset
x = X(:,100);

% ========================================================================
% STANDARDIZZAZIONE DELLO SPETTRO DI ESEMPIO
% ========================================================================
% Prima di proiettare sulla base PCA, lo spettro deve essere standardizzato
% usando la stessa media e deviazione standard del training set
xn = (x-Xm)./Xds;

% ========================================================================
% PROIEZIONE SULLA BASE DELLE COMPONENTI PRINCIPALI
% ========================================================================
% Calcola i coefficienti (scores) delle componenti principali
% c = U' * xn proietta lo spettro standardizzato sugli autovettori
% c(i) rappresenta "quanto" della componente principale i-esima è presente nello spettro
c = U'*xn;

% Visualizza i coefficienti in scala semi-logaritmica
% I coefficienti decrescono rapidamente: le ultime componenti contribuiscono poco
figure;
semilogx(c);

% ========================================================================
% RICOSTRUZIONE DELLO SPETTRO CON SOLE tau COMPONENTI
% ========================================================================
% Ricostruisce lo spettro usando solo le prime tau componenti principali
% xr = U(:,1:tau) * c(1:tau) combina solo le prime tau componenti
% Questa è la "compressione": da migliaia di canali a tau coefficienti
xr = U(:,1:tau)*c(1:tau);

% De-standardizzazione: riporta lo spettro ricostruito alle unità originali
% xr = xr * deviazione_standard + media
xr = xr.*Xds+Xm;

% ========================================================================
% CONFRONTO SPETTRO ORIGINALE VS RICOSTRUITO
% ========================================================================
% Plotta lo spettro originale e quello ricostruito
% La differenza mostra l'errore di ricostruzione dovuto al troncamento a tau componenti
figure;
plot(w,x,w,xr)
xlabel('wave number (cm^{-1})');
ylabel('Spettro W m^{-2} sr^{-1} (cm^{-1})^{-1}')
legend('Spettro originale','Spettro ricostruito')

% ========================================================================
% SALVATAGGIO DELLA BASE PCA PER USO FUTURO
% ========================================================================
% Salva gli elementi necessari per applicare la stessa trasformazione PCA
% ad altri spettri (ad esempio, per il retrieval)

% base.U: matrice degli autovettori (componenti principali)
base.U = U;

% base.Media: spettro medio del training set (necessario per standardizzazione)
base.Media = Xm;

% base.SD: deviazione standard del training set (necessario per standardizzazione)
base.SD = Xds;

% Salva la struttura "base" nel file base.mat
% Questo file verrà caricato negli algoritmi di retrieval
save base.mat base -mat