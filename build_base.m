function risultati_bande = build_base(bande_input, nomi_bande)
    %% CONTROLLI
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
    
    %% 2. CARICAMENTO DATI IASI
    fprintf('Caricamento dati IASI...\n');
    load resources/IASI.mat d
    rumore_strumentale_completo = load('resources/nednL1C.txt');
    
    risoluzione_spettrale = 0.25;
    numeri_onda_completi = (645:risoluzione_spettrale:2760)';
    indici_spettri_validi = find(d.avhrr_lf == 100 & d.avhrr_cf <= 10 & d.fovn == 1);
    num_spettri_validi = length(indici_spettri_validi);
    
    risultati_bande = cell(numero_bande, 1);

   % Init array vuoto
    base_dati = struct('autovettori', {}, 'radianza_media', {}, 'rumore_strumentale', {});
    
    %% CICLO PRINCIPALE SULLE BANDE
    for k = 1:numero_bande
        inizio_banda = bande_spettrali(k, 1);
        fine_banda = bande_spettrali(k, 2);
        nome_gas = nomi_bande{k};
        
        fprintf('\n--- Elaborazione BANDA %d: %s ---\n', k, nome_gas);
        
        indice_inizio_banda = fix((inizio_banda - numeri_onda_completi(1)) / risoluzione_spettrale) + 1;
        indice_fine_banda = fix((fine_banda - numeri_onda_completi(1)) / risoluzione_spettrale) + 1;
        numeri_onda_banda = numeri_onda_completi(indice_inizio_banda:indice_fine_banda);
        
        radianze_banda = d.rad(indice_inizio_banda:indice_fine_banda, indici_spettri_validi);
        rumore_strumentale_banda = rumore_strumentale_completo(indice_inizio_banda:indice_fine_banda);
        radianza_media = mean(radianze_banda, 2);
        
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
        
        coefficienti_proiezione = autovettori(:, 1:num_componenti_principali)' * radianze_standardizzate;
        radianze_standard_ricostruite = autovettori(:, 1:num_componenti_principali) * coefficienti_proiezione;
        radianze_ricostruite = (radianze_standard_ricostruite .* rumore_strumentale_banda) + radianza_media;
        
        residui_ricostruzione = radianze_banda - radianze_ricostruite;
        rmsd_ricostruzione = sqrt(mean(residui_ricostruzione.^2, 2));
        
        fig_rmsd = k * 10 + 1; 
        figure(fig_rmsd); clf;
        plot(numeri_onda_banda, rmsd_ricostruzione, 'b', 'LineWidth', 1.2); hold on; 
        plot(numeri_onda_banda, rumore_strumentale_banda, 'r--', 'LineWidth', 1.5); hold off;
        title(sprintf('BANDA %d (%s) - RMSD Ricostruzione vs Rumore', k, nome_gas));
        xlabel('Numero d''onda [cm^{-1}]'); ylabel('Radianza [mW / (m^2 sr cm^{-1})]');
        legend(sprintf('RMSD Ricostruzione (\\tau = %d)', num_componenti_principali), 'Rumore Strumentale', 'Location', 'Best'); grid on; xlim([inizio_banda fine_banda]);
        
        [rapporto_bonus, dev_std_bonus] = calcola_bonus(num_componenti_principali, autovettori, radianze_standardizzate, rumore_strumentale_banda, numeri_onda_banda, inizio_banda, fine_banda, k, nome_gas);
        
        % 1. Salvataggio nel Cell Array Avanzato
        base_dati_locale.nome = nome_gas;
        base_dati_locale.inizio = inizio_banda;
        base_dati_locale.fine = fine_banda;
        base_dati_locale.autovettori = autovettori;
        base_dati_locale.radianza_media = radianza_media;
        base_dati_locale.rumore_strumentale = rumore_strumentale_banda;
        base_dati_locale.rapporto_bonus = rapporto_bonus;
        base_dati_locale.dev_std_bonus = dev_std_bonus;
        
        risultati_bande{k} = base_dati_locale;
        
        % Array di struct
        base_dati(k).autovettori = autovettori;
        base_dati(k).radianza_media = radianza_media;
        base_dati(k).rumore_strumentale = rumore_strumentale_banda;
        
    end
    
    save('base_tutte_le_bande.mat', 'risultati_bande', '-mat');
    save('base.mat', 'base_dati', '-mat'); 
    
    fprintf('\n>>> Elaborazione Completata! File salvati. <<<\n');
end

