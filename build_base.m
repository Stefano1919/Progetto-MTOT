function risultati_bande = build_base(bande_input, nomi_bande)
    moltiplicatore_soglia =  60.0;
    
    if isvector(bande_input) && length(bande_input) > 2
        bande_spettrali = [bande_input(1:end-1)', bande_input(2:end)'];
    elseif isvector(bande_input) && length(bande_input) == 2
        bande_spettrali = bande_input(:)'; 
    else
        bande_spettrali = bande_input;
    end
    
    numero_bande = size(bande_spettrali, 1);
    
    if nargin < 3 || isempty(nomi_bande)
        nomi_bande = cell(numero_bande, 1);
        for i = 1:numero_bande
            nomi_bande{i} = sprintf('Spettro %.1f - %.1f', bande_spettrali(i,1), bande_spettrali(i,2));
        end
    end
    
    %% Caricamento dati da IASI
    load resources/IASI.mat d
    rumore_strumentale_completo = load('resources/nednL1C.txt');
    
    risoluzione_spettrale = 0.25;
    numeri_onda_completi = (645:risoluzione_spettrale:2760)';
    indici_spettri_validi = find(d.avhrr_lf == 100 & d.avhrr_cf <= 10 & d.fovn == 1);
    num_spettri_validi = length(indici_spettri_validi);
    
    latitudini_mappa = d.lat(indici_spettri_validi);
    longitudini_mappa = d.lon(indici_spettri_validi);
    
    risultati_bande = cell(numero_bande, 1);
    base_dati = struct('autovettori', {}, 'radianza_media', {}, 'rumore_strumentale', {});
    
    %% CICLO SULLE BANDE
    for k = 1:numero_bande
        inizio_banda = bande_spettrali(k, 1);
        fine_banda = bande_spettrali(k, 2);
        nome_gas = nomi_bande{k};
        
        fprintf('\n--- Elaborazione BANDA %d: %s ---\n', k, nome_gas);
        
        % Indici e Dati
        indice_inizio_banda = fix((inizio_banda - numeri_onda_completi(1)) / risoluzione_spettrale) + 1;
        indice_fine_banda = fix((fine_banda - numeri_onda_completi(1)) / risoluzione_spettrale) + 1;
        numeri_onda_banda = numeri_onda_completi(indice_inizio_banda:indice_fine_banda);
        
        radianze_banda = d.rad(indice_inizio_banda:indice_fine_banda, indici_spettri_validi);
        rumore_strumentale_banda = rumore_strumentale_completo(indice_inizio_banda:indice_fine_banda);
        radianza_media = mean(radianze_banda, 2);
        
        % PCA
        radianze_standardizzate = (radianze_banda - radianza_media) ./ rumore_strumentale_banda;
        matrice_covarianza = (1 / num_spettri_validi) * (radianze_standardizzate * radianze_standardizzate');
        [autovettori, autovalori, ~] = svd(matrice_covarianza);
        
        autovalori_singoli = diag(autovalori); 
        tot_canali = length(autovalori_singoli);
        indice_inizio_coda = floor(tot_canali / 2);
        livello_rumore_fondo = mean(autovalori_singoli(indice_inizio_coda:end));
        
        soglia_dinamica = livello_rumore_fondo * moltiplicatore_soglia; 
        num_componenti_principali = sum(autovalori_singoli > soglia_dinamica); 
        
        if num_componenti_principali < 7
            num_componenti_principali = 7;
        end
        fprintf('    Scelte %d PC (Soglia adattiva: %.2f)\n', num_componenti_principali, soglia_dinamica);
        
        % Ricostruzione
        coefficienti_proiezione = autovettori(:, 1:num_componenti_principali)' * radianze_standardizzate;
        radianze_standard_ricostruite = autovettori(:, 1:num_componenti_principali) * coefficienti_proiezione;
        radianze_ricostruite = (radianze_standard_ricostruite .* rumore_strumentale_banda) + radianza_media;
        
        residui_ricostruzione = radianze_banda - radianze_ricostruite;
        bias_ricostruzione = mean(residui_ricostruzione, 2);
        rmsd_ricostruzione = sqrt(mean(residui_ricostruzione.^2, 2));
       
        % per non sovrascrivere i grafici 
        fig_offset = k * 10; 
        
        %  Dati Fisici di Base (Spettri, Media, Rumore)
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
        
        % PCA (Autovalori e primi 10 Autovettori per compattezza)
        figure(fig_offset + 2); clf;
        subplot(2, 5, [1 5]); % L'autovalore prende la riga alta
        semilogy(autovalori_singoli, 'b', 'LineWidth', 1.5);
        title(sprintf('BANDA %d (%s) - Autovalori Componenti Principali', k, nome_gas));
        xlabel('Indice Componente'); ylabel('Autovalore (Log)'); grid on;
        
        for i = 1:5 
            subplot(2, 5, 5 + i);
            plot(numeri_onda_banda, autovettori(:, i));
            title(sprintf('PC %d', i)); grid on;
        end
        
        % Metriche (Bias e RMSD) 
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
        
        % Mappe Geografiche (Uso il canale a metà della banda) 
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
        
        %% BONUS
        [rapporto_bonus, dev_std_bonus] = calcola_bonus(num_componenti_principali, autovettori, radianze_standardizzate, rumore_strumentale_banda, numeri_onda_banda, inizio_banda, fine_banda, k, nome_gas);
        
       %% Salvataggio dati
        base_dati_locale.nome = nome_gas;
        base_dati_locale.inizio = inizio_banda;
        base_dati_locale.fine = fine_banda;
        base_dati_locale.autovettori = autovettori;
        base_dati_locale.radianza_media = radianza_media;
        base_dati_locale.rumore_strumentale = rumore_strumentale_banda;
        base_dati_locale.rapporto_bonus = rapporto_bonus;
        base_dati_locale.dev_std_bonus = dev_std_bonus;
        
        risultati_bande{k} = base_dati_locale;
        
        base_dati(k).autovettori = autovettori;
        base_dati(k).radianza_media = radianza_media;
        base_dati(k).rumore_strumentale = rumore_strumentale_banda;
        
    end
    save('base_tutte_le_bande.mat', 'risultati_bande', '-mat');
    save('base.mat', 'base_dati', '-mat'); 
    
end