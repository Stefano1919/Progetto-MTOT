close all; clear all;

%% Caricamento dati IASI

load IASI.mat
rumore = load('nednL1C.txt');
angoliVista = d.vza;
fov = d.fovn;
frazioneNuvolosa = d.avhrr_cf;
frazioneTerra = d.avhrr_lf;

%Scegliamo da frazione terra solo i dati con 100 (Significa che scegliamo
%terra)

% ??
indici_ok = find(frazioneTerra == 100 & frazioneNuvolosa < 20 & fov == 1);

% Definiamo la banda spettarle che ci interessa 
w1 = 2450.0;
w2 = 3550.0;
dw = 0.25; 

wave = [w1:dw:w2]';

nb1 = fix(w1-wave(1))/dw+1;
nb2 = fix(w2-wave(1))/dw+1;


