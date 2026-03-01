function risultati_bande = build_base(bande_input, terreno_selezionato, fov_selezionato, nubi_max, nomi_bande)
% BUILD_BASE Esegue l'analisi delle Componenti Principali (PCA), filtraggio e
% ricostruzione su finestre spettrali deglis pettri di IASI
% La funzione applica un criterio di rumore empirico (diverso dal criterio di Kaiser) per la scelta di tau.

% Parametro per la definizione della soglia di taglio del rumore
moltiplicatore_soglia =  60.0;

%% GESTIONE DEGLI INPUT
if isvector(bande_input) && length(bande_input) > 2
    bande_spettrali = [bande_input(1:end-1)', bande_input(2:end)'];
elseif isvector(bande_input) && length(bande_input) == 2
    bande_spettrali = bande_input(:)';
else
    bande_spettrali = bande_input;
end
numero_bande = size(bande_spettrali, 1);

% Generazione automatica dei nomi delle bande se non sono forniti
if nargin < 5 || isempty(nomi_bande)
    nomi_bande = cell(numero_bande, 1);
    for i = 1:numero_bande
        nomi_bande{i} = sprintf('Spettro %.1f - %.1f', bande_spettrali(i,1), bande_spettrali(i,2));
    end
end

%% CARICAMENTO DATI DA IASI
% d: struttura contenente le radianze e i metadati geografici
load resources/IASI.mat d
% Rumore strumentale
rumore_strumentale_completo = load('resources/nednL1C.txt');

risoluzione_spettrale = 0.25;
numeri_onda_completi = (645:risoluzione_spettrale:2760)';

% Filtraggio dei pixel in base alla scelta dell'utente
if strcmpi(terreno_selezionato, 'Terra')
    valore_terreno = 100; % Terra
else
    valore_terreno = 0;   % Mare/oceano
end

% Selezioniamo solo i pixel validi in base a: tipo di superficie, copertura
% nuvolos e uno specifico Field of View (FOV)
indici_spettri_validi = find(d.avhrr_lf == valore_terreno & d.avhrr_cf <= nubi_max & d.fovn == fov_selezionato);
num_spettri_validi = length(indici_spettri_validi);

latitudini_mappa = d.lat(indici_spettri_validi);
longitudini_mappa = d.lon(indici_spettri_validi);

risultati_bande = cell(numero_bande, 1);
base_dati = struct('autovettori', {}, 'radianza_media', {}, 'rumore_strumentale', {});

%% CICLO SULLE BANDE SPETTRALI
for k = 1:numero_bande
    inizio_banda = bande_spettrali(k, 1);
    fine_banda = bande_spettrali(k, 2);
    nome_gas = nomi_bande{k};
    fprintf('\n--- Elaborazione BANDA %d: %s ---\n', k, nome_gas);
    
    % Mappatura delle frequenze fisiche sugli indici degli array
    indice_inizio_banda = fix((inizio_banda - numeri_onda_completi(1)) / risoluzione_spettrale) + 1;
    indice_fine_banda = fix((fine_banda - numeri_onda_completi(1)) / risoluzione_spettrale) + 1;
    numeri_onda_banda = numeri_onda_completi(indice_inizio_banda:indice_fine_banda);
    
    radianze_banda = d.rad(indice_inizio_banda:indice_fine_banda, indici_spettri_validi);
    rumore_strumentale_banda = rumore_strumentale_completo(indice_inizio_banda:indice_fine_banda);
    
    % spettro medio
    radianza_media = mean(radianze_banda, 2);
    
    %% PCA E SCELTA DELLE COMPONENTI PRINCIPALI (TAU)
    
    % Standardizzazione
    % Si sottrae la media e si divide per il rumore strumentale NEDN. 
    % Questo garantisce che la PCA cerchi la varianza legata alla fisica
    % atmosferica e non venga ingannata dal rumore intrinseco dei canali.
    radianze_standardizzate = (radianze_banda - radianza_media) ./ rumore_strumentale_banda;
    
    % Decomposizione a Valori Singolari (SVD)
    matrice_covarianza = (1 / num_spettri_validi) * (radianze_standardizzate * radianze_standardizzate');
    [autovettori, autovalori, ~] = svd(matrice_covarianza);
    autovalori_singoli = diag(autovalori);
    tot_canali = length(autovalori_singoli);
    
    % Criterio del rumore empirico per la scelta dinamica di Tau
    % Gli autovalori descrivono l'energia di ciascuna componente. Poiché il 
    % segnale fisico decade rapidamente, la seconda metà delle PC contiene 
    % esclusivamente rumore bianco Gaussiano. Usiamo questa "coda" per 
    % stimare il rumore di fondo reale dei nostri dati.
    indice_inizio_coda = floor(tot_canali / 2);
    livello_rumore_fondo = mean(autovalori_singoli(indice_inizio_coda:end));
    
    % Taglio "automatico"
    % Imponiamo che una PC sia considerata un segnale pricipale solo se la sua
    % energia è nettamente superiore al rumore di fondo stimato empiricamente.
    soglia_dinamica = livello_rumore_fondo * moltiplicatore_soglia;
    num_componenti_principali = sum(autovalori_singoli > soglia_dinamica);
    
    %  Underfitting
    % Se le finestre spettrali sono molto trasparenti impostiamo a 7 il
    % valore di tau
    if num_componenti_principali < 7
        num_componenti_principali = 7;
    end
    fprintf('    Scelte %d PC (Soglia adattiva: %.2f)\n', num_componenti_principali, soglia_dinamica);
    
  
    %% RICOSTRUZIONE E METRICHE
    % Proiezione nel sottospazio atmosferico a dimensionalità ridotta (tau)
    coefficienti_proiezione = autovettori(:, 1:num_componenti_principali)' * radianze_standardizzate;
    
    % Ricostruzione del segnale filtrato dal rumore
    radianze_standard_ricostruite = autovettori(:, 1:num_componenti_principali) * coefficienti_proiezione;
    
    % Ritorno allo spazio fisico moltiplicando per il NEDN
    radianze_ricostruite = (radianze_standard_ricostruite .* rumore_strumentale_banda) + radianza_media;
    
    % Calcolo dei residui 
    residui_ricostruzione = radianze_banda - radianze_ricostruite;
    bias_ricostruzione = mean(residui_ricostruzione, 2);
    rmsd_ricostruzione = sqrt(mean(residui_ricostruzione.^2, 2));
    

    %% GRAFICI
    % L'offset garantisce che ogni banda apra un set di finestre separate
    fig_offset = k * 10;
    
    % Dati Fisici di Base (Spettri, Media, Rumore)
    figure(fig_offset + 1); clf;
    subplot(3,1,1);
    numero_spettri_visualizzati = min(50, num_spettri_validi);
    plot(numeri_onda_banda, radianze_banda(:, 1:numero_spettri_visualizzati));
    title(sprintf('BANDA %d (%s) - Primi %d Spettri IASI', k, nome_gas, numero_spettri_visualizzati));
    ylabel('Radianza'); grid on; xlim([inizio_banda fine_banda]);
    subplot(3,1,2);
    plot(numeri_onda_banda, radianza_media, 'k', 'LineWidth', 1.2);
    title('Spettro Medio'); ylabel('Radianza Media'); grid on; xlim([inizio_banda fine_banda]);
    subplot(3,1,3);
    plot(numeri_onda_banda, rumore_strumentale_banda, 'r', 'LineWidth', 1.2);
    title('Rumore Strumentale'); xlabel('Numero d''onda [cm^{-1}]'); ylabel('Rumore'); grid on; xlim([inizio_banda fine_banda]);
    
    % PCA
    figure(fig_offset + 2); clf;
    subplot(2, 5, [1 5]); 
    semilogy(autovalori_singoli, 'b', 'LineWidth', 1.5);
    title(sprintf('BANDA %d (%s) - Autovalori Componenti Principali', k, nome_gas));
    xlabel('Indice Componente'); ylabel('Autovalore (Log)'); grid on;
    for i = 1:5
        subplot(2, 5, 5 + i);
        plot(numeri_onda_banda, autovettori(:, i));
        title(sprintf('PC %d', i)); grid on;
    end
    
    % Metriche (Bias e Validazione RMSD)
    % L'RMSD dovrebbe idealmente stare al di sotto del rumore strumentale
    figure(fig_offset + 3); clf;
    subplot(2, 1, 1);
    plot(numeri_onda_banda, bias_ricostruzione, 'b', 'LineWidth', 1.2);
    yline(0, 'r--', 'LineWidth', 1.5);
    title(sprintf('BANDA %d (%s) - Bias della Ricostruzione (\\tau = %d)', k, nome_gas, num_componenti_principali));
    ylabel('Bias [Radianza]'); grid on; xlim([inizio_banda fine_banda]);
    subplot(2, 1, 2);
    plot(numeri_onda_banda, rmsd_ricostruzione, 'k', 'LineWidth', 1.2); hold on;
    plot(numeri_onda_banda, rumore_strumentale_banda, 'r--', 'LineWidth', 1.5); hold off;
    title('RMSD della Ricostruzione vs Rumore Strumentale');
    xlabel('Numero d''onda [cm^{-1}]'); ylabel('Radianza');
    legend('RMSD Ricostruzione', 'Rumore Strumentale', 'Location', 'Best'); grid on; xlim([inizio_banda fine_banda]);
    
    % Confronto Spettro Singolo Originale vs Ricostruito
    indice_spettro_test = min(100, num_spettri_validi);
    figure(fig_offset + 4); clf;
    plot(numeri_onda_banda, radianze_banda(:, indice_spettro_test), 'b', 'LineWidth', 1.5); hold on;
    plot(numeri_onda_banda, radianze_ricostruite(:, indice_spettro_test), 'r', 'LineWidth', 1.5); hold off;
    title(sprintf('BANDA %d (%s) - Confronto (Spettro #%d, \\tau = %d)', k, nome_gas, indice_spettro_test, num_componenti_principali));
    xlabel('Numero d''onda [cm^{-1}]'); ylabel('Radianza');
    legend('Spettro Originale', 'Spettro Ricostruito', 'Location', 'Best'); grid on; xlim([inizio_banda fine_banda]);
    
    % Mappe Geografiche
    indice_canale_mappa = floor(tot_canali / 2);
    numero_onda_mappa = numeri_onda_banda(indice_canale_mappa);
    radianza_originale_mappa = radianze_banda(indice_canale_mappa, :);
    radianza_ricostruita_mappa = radianze_ricostruite(indice_canale_mappa, :);
    errore_ricostruzione_mappa = residui_ricostruzione(indice_canale_mappa, :);
    
    figure(fig_offset + 5); clf;
    subplot(1, 3, 1);
    geoscatter(latitudini_mappa, longitudini_mappa, 15, radianza_originale_mappa, 'filled', 'MarkerFaceAlpha', 0.7);
    colormap(jet); title(sprintf('BANDA %d: Orig. (%.1f cm^{-1})', k, numero_onda_mappa));
    subplot(1, 3, 2);
    geoscatter(latitudini_mappa, longitudini_mappa, 15, radianza_ricostruita_mappa, 'filled', 'MarkerFaceAlpha', 0.7);
    colormap(jet); title('Ricostruita');
    subplot(1, 3, 3);
    geoscatter(latitudini_mappa, longitudini_mappa, 15, abs(errore_ricostruzione_mappa), 'filled', 'MarkerFaceAlpha', 0.7);
    colormap(jet); title('Errore Assoluto');
    
    %% PUNTO BONUS
    [rapporto_bonus, dev_std_bonus] = calcola_bonus(num_componenti_principali, autovettori, radianze_standardizzate, rumore_strumentale_banda, numeri_onda_banda, inizio_banda, fine_banda, k, nome_gas);
    
    %% SALVATAGGIO DATI 
    base_dati_locale.nome = nome_gas;
    base_dati_locale.inizio = inizio_banda;
    base_dati_locale.fine = fine_banda;
    base_dati_locale.autovettori = autovettori;
    base_dati_locale.radianza_media = radianza_media;
    base_dati_locale.rumore_strumentale = rumore_strumentale_banda;
    base_dati_locale.rapporto_bonus = rapporto_bonus;
    base_dati_locale.dev_std_bonus = dev_std_bonus;
    risultati_bande{k} = base_dati_locale;
    
    % Struttura compatta per il retrieval
    base_dati(k).autovettori = autovettori;
    base_dati(k).radianza_media = radianza_media;
    base_dati(k).rumore_strumentale = rumore_strumentale_banda;
end

save('base_tutte_le_bande.mat', 'risultati_bande', '-mat');
save('base.mat', 'base_dati', '-mat');
end