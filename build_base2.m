close all; clear;

load IASI.mat
rumore_strumentale_completo = load('nednL1C.txt');

% Finestra spettrale N2O
inizio_banda = 2150.0;
fine_banda = 2250.0;
risoluzione_spettrale = 0.25;

% Finestra spettrale completa IASI
numeri_onda_completi = (645:risoluzione_spettrale:2760)';

[num_canali_totali, num_spettri_totali] = size(d.rad);

% Indici dei numeri d'onda per la banda N2O
indice_inizio_banda = fix((inizio_banda - numeri_onda_completi(1)) / risoluzione_spettrale) + 1;
indice_fine_banda = fix((fine_banda - numeri_onda_completi(1)) / risoluzione_spettrale) + 1;

indici_spettri_validi = find(d.avhrr_lf == 100 & d.avhrr_cf <= 10 & d.fovn == 1);

%% VISUALIZZAZIONE SPETTRI
radianze_banda = d.rad(indice_inizio_banda:indice_fine_banda, indici_spettri_validi);
[~, num_spettri_validi] = size(radianze_banda);

numeri_onda_banda = numeri_onda_completi(indice_inizio_banda:indice_fine_banda);

figure(1); clf;
numero_spettri_visualizzati = 50;
plot(numeri_onda_banda, radianze_banda(:, 1:numero_spettri_visualizzati));
title(sprintf('Spettri IASI - Banda N_2O (%.1f-%.1f cm^{-1})', inizio_banda, fine_banda));
xlabel('Numero d''onda [cm^{-1}]');
ylabel('Radianza [mW / (m^2 sr cm^{-1})]');
grid on;
xlim([inizio_banda fine_banda]);

%% STATISTICHE E PCA
radianza_media = mean(radianze_banda, 2);

figure(2); clf;
plot(numeri_onda_banda, radianza_media);
title('Spettro Medio');
xlabel('Numero d''onda [cm^{-1}]');
ylabel('Radianza Media [mW / (m^2 sr cm^{-1})]');
grid on;

rumore_strumentale_banda = rumore_strumentale_completo(indice_inizio_banda:indice_fine_banda);

figure(3); clf;
plot(numeri_onda_banda, rumore_strumentale_banda);
title('Rumore Strumentale');
xlabel('Numero d''onda [cm^{-1}]');
ylabel('Rumore [mW / (m^2 sr cm^{-1})]');
grid on;

% Standardizzazione
radianze_standardizzate = zeros(indice_fine_banda - indice_inizio_banda + 1, num_spettri_validi);
for i = 1:num_spettri_validi
    radianze_standardizzate(:, i) = (radianze_banda(:, i) - radianza_media) ./ rumore_strumentale_banda;
end

matrice_covarianza = (1 / num_spettri_validi) * (radianze_standardizzate * radianze_standardizzate');
[autovettori, autovalori, ~] = svd(matrice_covarianza);

figure(4); clf;
semilogy(diag(autovalori));
title('Autovalori delle Componenti Principali');
xlabel('Indice Componente Principale');
ylabel('Autovalore');
grid on;

figure(5); clf;
for i = 1:20
    subplot(5, 4, i);
    plot(numeri_onda_banda, autovettori(:, i));
    title(sprintf('PC %d', i));
end

%% RICOSTRUZIONE
num_componenti_principali = 7;

coefficienti_proiezione = autovettori(:, 1:num_componenti_principali)' * radianze_standardizzate;
radianze_standard_ricostruite = autovettori(:, 1:num_componenti_principali) * coefficienti_proiezione;
radianze_ricostruite = (radianze_standard_ricostruite .* rumore_strumentale_banda) + radianza_media;

%% METRICHE
residui_ricostruzione = radianze_banda - radianze_ricostruite;

bias_ricostruzione = mean(residui_ricostruzione, 2);
rmsd_ricostruzione = sqrt(mean(residui_ricostruzione.^2, 2));

figure(6); clf;
subplot(2, 1, 1);
plot(numeri_onda_banda, bias_ricostruzione, 'b', 'LineWidth', 1.2);
yline(0, 'r--', 'LineWidth', 1.5);
title(sprintf('Bias della Ricostruzione con %d Componenti', num_componenti_principali));
ylabel('Bias [Radianza]');
grid on;
xlim([inizio_banda fine_banda]);

subplot(2, 1, 2);
plot(numeri_onda_banda, rmsd_ricostruzione, 'k', 'LineWidth', 1.2);
hold on;
plot(numeri_onda_banda, rumore_strumentale_banda, 'r--', 'LineWidth', 1.5);
hold off;
title('RMSD della Ricostruzione vs Rumore Strumentale');
xlabel('Numero d''onda [cm^{-1}]');
ylabel('Radianza');
legend('RMSD Ricostruzione', 'Rumore Strumentale', 'Location', 'Best');
grid on;
xlim([inizio_banda fine_banda]);

%% MAPPE GEOGRAFICHE
indice_canale_mappa = 100;
numero_onda_mappa = numeri_onda_banda(indice_canale_mappa);

latitudini_mappa = d.lat(indici_spettri_validi);
longitudini_mappa = d.lon(indici_spettri_validi);
radianza_originale_mappa = radianze_banda(indice_canale_mappa, :);
radianza_ricostruita_mappa = radianze_ricostruite(indice_canale_mappa, :);
errore_ricostruzione_mappa = residui_ricostruzione(indice_canale_mappa, :);

figure(7); clf;
subplot(1, 2, 1);
geoscatter(latitudini_mappa, longitudini_mappa, 15, radianza_originale_mappa, 'filled', 'MarkerFaceAlpha', 0.7);
colormap(jet); colorbar;
title(sprintf('Radianza Originale (%.2f cm^{-1})', numero_onda_mappa));

subplot(1, 2, 2);
geoscatter(latitudini_mappa, longitudini_mappa, 15, radianza_ricostruita_mappa, 'filled', 'MarkerFaceAlpha', 0.7);
colormap(jet); colorbar;
title(sprintf('Radianza Ricostruita (%.2f cm^{-1})', numero_onda_mappa));

figure(8); clf;
geoscatter(latitudini_mappa, longitudini_mappa, 20, errore_ricostruzione_mappa, 'filled', 'MarkerFaceAlpha', 0.8);
colormap(jet); colorbar;
title(sprintf('Errore di Ricostruzione (%.2f cm^{-1})', numero_onda_mappa));

%% SALVATAGGIO
base_dati.autovettori = autovettori;
base_dati.radianza_media = radianza_media;
base_dati.rumore_strumentale = rumore_strumentale_banda;
save('base.mat', 'base_dati', '-mat');
