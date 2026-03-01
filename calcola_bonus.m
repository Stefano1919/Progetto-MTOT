function [rapporto, devStd_rumore_ricostruito] = calcola_bonus(tau, U, Xn, Xds, w, w1, w2, id_banda, nome_gas)
    % Verifica fisicamente che le PC scartate
    % contengano esclusivamente rumore strumentale e nessuna informazione atmosferica.
    %
    % INPUT:
    %   - tau: Numero di PC trattenute
    %   - U: Matrice completa degli autovettori
    %   - Xn: Matrice delle radianze standardizzat
    %   - Xds: Vettore del rumore strumentale di fabbrica 
    %   - w, w1, w2: Vettore dei numeri d'onda e limiti spettrali
    
    % Selezioniamo solo gli autovettori che vanno dalla componente tau+1 fino
    % all'ultima. Se il taglio di tau è corretto, queste direzioni non contengono 
    % più varianza legata alla fisica dei gas, ma solo rumore casuale.
    tot_componenti = size(U, 2);
    U_scartate = U(:, tau+1:tot_componenti);
    
    % Proiezione e Ricostruzione del Rumore
    % Proiettiamo i dati originari standardizzati lungo le direzioni scartate 
    % per ottenere i coefficienti (scores) del solo rumore.
    scores_rumore = U_scartate' * Xn;
    
    % Ricostruiamo il segnale di solo rumore nello spazio dei canali standardizzati
    Xn_rumore = U_scartate * scores_rumore;
    
    % De-standardizzazione: moltiplichiamo per il NEDN per riportare il rumore 
    % all'unità di misura fisica della Radianza [mW / (m^2 sr cm^-1)].
    rumore_fisico = Xn_rumore .* Xds;
    
    % Valutazione Statistica
    % Calcoliamo la deviazione standard del rumore estratto calcolandola lungo 
    % le colonne questa rappresenta la variabilità reale introdotta dallo strumento.
    devStd_rumore_ricostruito = std(rumore_fisico, 0, 2);
    
    % calcoliamo il rapporto medio tra il rumore reale estratto 
    % e il limite teorico
    rapporto = mean(devStd_rumore_ricostruito ./ Xds);
    
    % Grafici
    fig_bonus = id_banda * 10 + 2; 
    figure(fig_bonus); clf;
    plot(w, devStd_rumore_ricostruito, 'b', 'LineWidth', 1.5); hold on;
    plot(w, Xds, 'r--', 'LineWidth', 2); hold off;
    
    title(sprintf('BANDA %d (%s) - BONUS: Dev. Std. Scarti vs Rumore', id_banda, nome_gas));
    xlabel('Numero d''onda [cm^{-1}]'); 
    ylabel('Deviazione standard [Radianza]');
    legend('Dev Std PC Scartate', 'Rumore Strumentale Teorico', 'Location', 'Best'); 
    grid on; 
    xlim([w1 w2]);
end