tau = 10;

tot_componenti = size(U,2);

U_scartate = U(:, tau+1:tot_componenti);

scores = U_scartate' * Xn;

Xn_rumore = U_scartate * scores;

Rumrore_Fisico = Xn_rumore .* Xds;

DevStd_rumore_Ricostruito = std(Rumrore_Fisico, 0, 2);

figure(13); clf;
plot(w, DevStd_rumore_Ricostruito, 'b', 'LineWidth', 1.5);
hold on;
plot(w, Xds, 'r--', 'LineWidth', 2); % Il rumore strumentale teorico
hold off;
title('Deviazione standard PC scartate vs rumore strumentale');
xlabel('Numero d''onda [cm^{-1}]');
ylabel('Deviazione standard [Radianza]');
legend('Dev Std delle componenti Scartate', 'Rumore Strumentale Teorico', 'Location', 'Best');
grid on; xlim([w1 w2]);

rapporto = mean(DevStd_rumore_Ricostruito ./ Xds);