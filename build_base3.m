
%% VECCHIO
close all; clear; clc;

load resources/IASI.mat
rumore_strumentale_completo = load('resources/nednL1C.txt');

% 1. DEFINIZIONE DELLE MICRO-FINESTRE FISICHE
bande_spettrali = [
    645.0,   800.0;   % CO2
    800.0,   980.0;   % Finestra atmosferica che guarda alla superficie
    980.0,  1080.0;   % Ozono (O3)
    1210.0, 1600.0;   % Vapore Acqueo (H2O)
    2100.0, 2250.0    % Monossido di Carbonio (CO) e N2O
];

% Nomi descrittivi per i grafici TODO TOGLIERE
nomi_bande = {
    'Temperatura e CO_2', 
    'Finestra Atmosferica', 
    'Ozono (O_3)', 
    'Vapore Acqueo (H_2O)', 
    'N_2O e CO'
};

numero_bande = size(bande_spettrali, 1);

risoluzione_spettrale = 0.25;
numeri_onda_completi = (645:risoluzione_spettrale:2760)';

indici_spettri_validi = find(d.avhrr_lf == 100 & d.avhrr_cf <= 10 & d.fovn == 1);
num_spettri_validi = length(indici_spettri_validi);

risultati_bande = cell(numero_bande, 1);

%% CICLO PRINCIPALE SULLE BANDE FISICHE
for k = 1:numero_bande
    inizio_banda = bande_spettrali(k, 1);
    fine_banda = bande_spettrali(k, 2);
    nome_gas = nomi_bande{k};
    
    indice_inizio_banda = fix((inizio_banda - numeri_onda_completi(1)) / risoluzione_spettrale) + 1;
    indice_fine_banda = fix((fine_banda - numeri_onda_completi(1)) / risoluzione_spettrale) + 1;
    numeri_onda_banda = numeri_onda_completi(indice_inizio_banda:indice_fine_banda);
    
    radianze_banda = d.rad(indice_inizio_banda:indice_fine_banda, indici_spettri_validi);
    rumore_strumentale_banda = rumore_strumentale_completo(indice_inizio_banda:indice_fine_banda);
    
    radianza_media = mean(radianze_banda, 2);
    
    radianze_standardizzate = (radianze_banda - radianza_media) ./ rumore_strumentale_banda;
    
    matrice_covarianza = (1 / num_spettri_validi) * (radianze_standardizzate * radianze_standardizzate');
    [autovettori, autovalori, ~] = svd(matrice_covarianza);

    % CRITERIO DEL RUMORE EMPIRICO 
    autovalori_singoli = diag(autovalori); 
    tot_canali = length(autovalori_singoli);
    
    indice_inizio_coda = floor(tot_canali / 2);
    livello_rumore_fondo = mean(autovalori_singoli(indice_inizio_coda:end));
    
    soglia_dinamica = livello_rumore_fondo * 60.0; 
    
    % Taglio
    num_componenti_principali = sum(autovalori_singoli > soglia_dinamica); 
    
    % se prendo tau < 7 allora lo imposto a 7
    if num_componenti_principali < 7
        num_componenti_principali = 7;
    end
    
  
    coefficienti_proiezione = autovettori(:, 1:num_componenti_principali)' * radianze_standardizzate;
    radianze_standard_ricostruite = autovettori(:, 1:num_componenti_principali) * coefficienti_proiezione;
    
    % Ritorno allo spazio fisico
    radianze_ricostruite = (radianze_standard_ricostruite .* rumore_strumentale_banda) + radianza_media;
    
    residui_ricostruzione = radianze_banda - radianze_ricostruite;
    rmsd_ricostruzione = sqrt(mean(residui_ricostruzione.^2, 2));
    
    fig_rmsd = k * 10 + 1; 
    figure(fig_rmsd); clf;
    plot(numeri_onda_banda, rmsd_ricostruzione, 'y', 'LineWidth', 1.2); hold on;
    plot(numeri_onda_banda, rumore_strumentale_banda, 'r--', 'LineWidth', 1.5); hold off;
    
    title(sprintf('BANDA %d (%s) - RMSD Ricostruzione vs Rumore', k, nome_gas));
    xlabel('Numero d''onda [cm^{-1}]'); 
    ylabel('Radianza [mW / (m^2 sr cm^{-1})]');
legend(sprintf('RMSD Ricostruzione (\\tau = %d)', num_componenti_principali), 'Rumore Strumentale', 'Location', 'Best');    grid on; xlim([inizio_banda fine_banda]);
    
    [rapporto_bonus, dev_std_bonus] = bonus(num_componenti_principali, autovettori, radianze_standardizzate, rumore_strumentale_banda, numeri_onda_banda, inizio_banda, fine_banda, k, nome_gas);

    % Salvataggio dati locale
    base_dati_locale.nome = nome_gas;
    base_dati_locale.inizio = inizio_banda;
    base_dati_locale.fine = fine_banda;
    base_dati_locale.autovettori = autovettori;
    base_dati_locale.radianza_media = radianza_media;
    base_dati_locale.rumore_strumentale = rumore_strumentale_banda;
    base_dati_locale.rapporto_bonus = rapporto_bonus;
    
    risultati_bande{k} = base_dati_locale;

    base_dati(k).autovettori = autovettori;
    base_dati(k).radianza_media = radianza_media;
    base_dati(k).rumore_strumentale = rumore_strumentale_banda;
end

%% SALVATAGGIO FINALE
save('base_tutte_le_bande.mat', 'risultati_bande', '-mat');
save('base.mat', 'base_dati', '-mat'); 

function [rapporto, devStd_rumore_ricostruito] = bonus(tau, U, Xn, Xds, w, w1, w2, id_banda, nome_gas)
    % 1. Isolo le componenti del rumore (sottospazio nullo)
    tot_componenti = size(U, 2);
    U_scartate = U(:, tau+1:tot_componenti);
    
    % 2. Proiezione e Ricostruzione (solo deviazione, no media)
    scores_rumore = U_scartate' * Xn;
    Xn_rumore = U_scartate * scores_rumore;
    rumore_fisico = Xn_rumore .* Xds;
    
    % 3. Statistica
    devStd_rumore_ricostruito = std(rumore_fisico, 0, 2);
    rapporto = mean(devStd_rumore_ricostruito ./ Xds);
    
    % 4. Grafico Bonus
    fig_bonus = id_banda * 10 + 2; % Es. Figura 12, 22, 32...
    figure(fig_bonus); clf;
    plot(w, devStd_rumore_ricostruito, 'b', 'LineWidth', 1.5); hold on;
    plot(w, Xds, 'r--', 'LineWidth', 2); hold off;
    
    title(sprintf('BANDA %d (%s) - BONUS: Dev. Std. Scarti vs Rumore', id_banda, nome_gas));
    xlabel('Numero d''onda [cm^{-1}]'); 
    ylabel('Deviazione standard [Radianza]');
    legend('Dev Std PC Scartate', 'Rumore Strumentale Teorico', 'Location', 'Best');
    grid on; xlim([w1 w2]);
    
end