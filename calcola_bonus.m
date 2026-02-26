function [rapporto, devStd_rumore_ricostruito] = calcola_bonus(tau, U, Xn, Xds, w, w1, w2, id_banda, nome_gas)
    tot_componenti = size(U, 2);
    U_scartate = U(:, tau+1:tot_componenti);
    
    scores_rumore = U_scartate' * Xn;
    Xn_rumore = U_scartate * scores_rumore;
    rumore_fisico = Xn_rumore .* Xds;
    
    devStd_rumore_ricostruito = std(rumore_fisico, 0, 2);
    rapporto = mean(devStd_rumore_ricostruito ./ Xds);
    
    fig_bonus = id_banda * 10 + 2; 
    figure(fig_bonus); clf;
    plot(w, devStd_rumore_ricostruito, 'b', 'LineWidth', 1.5); hold on;
    plot(w, Xds, 'r--', 'LineWidth', 2); hold off;
    title(sprintf('BANDA %d (%s) - BONUS: Dev. Std. Scarti vs Rumore', id_banda, nome_gas));
    xlabel('Numero d''onda [cm^{-1}]'); ylabel('Deviazione standard [Radianza]');
    legend('Dev Std PC Scartate', 'Rumore Strumentale Teorico', 'Location', 'Best'); grid on; xlim([w1 w2]);
end