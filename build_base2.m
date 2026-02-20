close all; clear all

load IASI.mat
rumore = load('nednL1C.txt');

% Finestra spettrale n2o in cm^-1
w1 = 2150.0;  
w2 = 2250.0;  
dw = 0.25;   % Risoluzione

% Finestra spettrale completa di IASI
wave = [645:dw:2760]';  

% n1: numero di canali spettrali
% n2: numero di profili atmosferici (spettri diversi)
% n3: numero di angoli di vista (FOV - Field Of View)
n3 = 1;
[n1,n2] = size(d.rad);

% Calcoliamo gli indici dei numeri d'onda
nb1 = fix(w1-wave(1))/dw+1;


nb2 = fix(w2-wave(1))/dw+1;

indici_ok = find(d.avhrr_lf == 100 & d.avhrr_cf <= 10 & d.fovn == 1);


%% VISUALIZZAZIONE SPETTRI
X = d.rad(nb1:nb2, indici_ok); 
[~, n2_filtrati] = size(X);
% Estrae il vettore dei numeri d'onda corrispondente (Asse X)
w = wave(nb1:nb2);


figure(1); clf; 

% Plottiamo solo i primi 50 spettri per non far esplodere il pc :)
numero_spettri_da_plottare = 50; 

plot(w, X(:, 1:numero_spettri_da_plottare));
title(['Spettri IASI - Banda N_2O (' num2str(w1) '-' num2str(w2) ' cm^{-1})']);
xlabel('Numero d''onda [cm^{-1}]');
ylabel('Radianza [mW / (m^2 sr cm^{-1})]');
grid on;
xlim([w1 w2])

%% Calcolo statistiche spettri 
% Calcola lo spettro medio dell'intero dataset
% mean(X,2) calcola la media lungo le colonne (dimensione 2)
% Ogni elemento di Xm è la radianza media per quel canale spettrale
Xm  = mean(X,2);

% Plotta lo spettro medio
figure; 
plot(w,Xm)

% Plotta la deviazione standard
% Mostra quali canali spettrali hanno maggiore variabilità
% Alta variabilità → più informazione sulla variabilità atmosferica



% Estraiamo solo il pezzo che ci serve per la n2o
rumore_n2o = rumore(nb1:nb2);

Xds = rumore_n2o;
figure; 
plot(w,Xds)
% La standardizzazione è fondamentale per la PCA:
% - Rimuove il valore medio (centra i dati)
% - Normalizza per la deviazione standard (rende i canali comparabili)

% Inizializza la matrice degli spettri standardizzati
Xn = zeros(nb2-nb1+1,n2_filtrati);

% Loop su tutti gli spettri
for i=1:n2_filtrati
    Xn(:,i) = (X(:,i)-Xm)./Xds;
end


% La matrice di covarianza misura come variano insieme i diversi canali spettrali
% C(i,j) rappresenta la covarianza tra il canale i e il canale j
C = (1/n2_filtrati)*(Xn*Xn');

% SVD decompone la matrice di covarianza: C = U * S * V'
% U: matrice degli autovettori (componenti principali) - direzioni di massima varianza
% S: matrice diagonale degli autovalori - varianza spiegata da ogni componente
% V: in questo caso V=U perché C è simmetrica
% Gli autovettori sono ordinati per autovalore decrescente
[U,S,V] = svd(C);

figure;
semilogy(diag(S))
title("Autovalori delle componenti principali")

%Prime 20 pc
figure;
for i=1:20
    subplot(5,4,i) 
    plot(wave(nb1:nb2),U(:,i))
    title(["PC " num2str(i)]);
end

%% RICOSTRUZIONE SPETTRO
tau = 7; % Taglio delle componenti

% Proiezione
scores = U(:, 1:tau)' * Xn;

% Ricostruzione spettri
Xn_ricostruiti = U(:, 1:tau) * scores;

% torniamo indietro dala standardizzazione
X_ricostruito = (Xn_ricostruiti .* Xds) + Xm;

%% METRCIHE
Residui = X - X_ricostruito;

% 2 perché lungo le colonne ci sono gli spettri
Bias = mean(Residui, 2);
RMSD = sqrt(mean(Residui.^2, 2));


figure(10); clf;

subplot(2,1,1);
plot(w, Bias, 'b', 'LineWidth', 1.2);
yline(0, 'r--', 'LineWidth', 1.5);
title(['Bias della Ricostruzione con \tau = ' num2str(tau)]);
ylabel('Bias [Radianza]');
grid on; xlim([w1 w2]);

% --- Grafico RMSD ---
subplot(2,1,2);
plot(w, RMSD, 'k', 'LineWidth', 1.2);
hold on;
plot(w, Xds, 'r--', 'LineWidth', 1.5);
hold off;
title('RMSD della Ricostruzione vs rumore strumentale');
xlabel('Numero d''onda [cm^{-1}]');
ylabel('RMSD [Radianza]');
legend('RMSD Ricostruzione', ' rumore strumentale', 'Location', 'Best');
grid on; xlim([w1 w2]);

%% MAPPE 
canale_test = 100;
freq_test = w(canale_test);

lat_map = d.lat(indici_ok);
lon_map = d.lon(indici_ok);
radianza_vera = X(canale_test, :);
radianza_ricostruita = X_ricostruito(canale_test, :);
errore_mappa = Residui(canale_test, :);

figure(11); clf;
% mappa radianza or
subplot(1,2,1);
geoscatter(lat_map, lon_map, 15, radianza_vera, 'filled', 'MarkerFaceAlpha', 0.7);
colormap(jet); colorbar;
title(['Radianza Originale a ' num2str(freq_test) ' cm^{-1}']);

% mappa radianza ricostruita
subplot(1,2,2);
geoscatter(lat_map, lon_map, 15, radianza_ricostruita, 'filled', 'MarkerFaceAlpha', 0.7);
colormap(jet); colorbar;
title(['Radianza Ricostruita a ' num2str(freq_test) ' cm^{-1}']);

% Mappa errore
figure(12); clf;
geoscatter(lat_map, lon_map, 20, errore_mappa, 'filled', 'MarkerFaceAlpha', 0.8);
colormap(jet); 
colorbar;
title(['Errore ' num2str(freq_test) ' cm^{-1}']);
%% SASLVATAGGIO BASE
base.U = U;
base.Media = Xm;
base.SD = Xds;
save base.mat base -mat

