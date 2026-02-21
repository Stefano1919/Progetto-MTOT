function [rapporto, devStd_rumore_ricostruito] = bonus(tau, U, Xn, Xds, w, w1, w2)
    tot_componenti = size(U, 2);
    U_scartate = U(:, tau+1:tot_componenti);
    scores_rumore = U_scartate' * Xn;
    Xn_rumore = U_scartate * scores_rumore;
    rumore_fisico = Xn_rumore .* Xds;
    
    devStd_rumore_ricostruito = std(rumore_fisico, 0, 2);
    rapporto = mean(devStd_rumore_ricostruito ./ Xds);
    
    figure(13); clf;
    
    plot(w, devStd_rumore_ricostruito, 'b', 'LineWidth', 1.5);
    hold on;
    
    plot(w, Xds, 'r--', 'LineWidth', 2); 
    hold off;
    title(sprintf('Deviazione Standard PC Scartate vs Rumore Strumentale (\\tau = %d)', tau));
    xlabel('Numero d''onda [cm^{-1}]');
    ylabel('Deviazione standard [Radianza]');
    legend('Dev Std componenti scartate', 'Rumore Strumentale Teorico', 'Location', 'Best');
    grid on; 
    xlim([w1 w2]);
   
end