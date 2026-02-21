classdef App < handle
    %APP Classe principale dell'applicazione
    %   Gestisce la finestra principale e coordina Model, View e Controller

    properties
        Figure(:, 1) matlab.ui.Figure
        Modello(:, 1) Model
        Layout(:, 1)
        VistaGrafici(:, 1) PlotView
        Controller(:, 1) Controller
        TabController(:, 1) TabController
    end

    methods
        function obj = App()

            modello = Model();
            obj.Modello = modello;

            %% Configurazione finestra principale
            obj.Figure = uifigure("Visible", "off");
            obj.Figure.Name = "Sensori-Rivelatori-Dispositivi-Elettronici-2024-2025";
            obj.Figure.Units = "normalized";
            obj.Figure.Position = [0,0,1,1];
            obj.Figure.WindowState = "maximized";
            obj.Figure.Theme = 'light';

            %% Configurazione layout

            obj.Layout = uigridlayout("Parent", obj.Figure);
            obj.Layout.RowHeight = "1x";
            obj.Layout.ColumnWidth = {'0.2x', '0.8x'};

            %% Configurazione controlli
            obj.TabController = TabController();
            obj.Controller = Controller("Parent", obj.Layout);
            obj.TabController.App = obj;

            %% Configurazione vista

            obj.VistaGrafici = PlotView("Parent", obj.Layout);

            %% Dipendenze
            obj.VistaGrafici.App = obj;
            obj.Modello.App = obj;
            obj.Controller.App = obj;

            obj.VistaGrafici.Subscribe();

            obj.Figure.Visible = "on";
        end

        function showError(obj, message)
            uialert(obj.Figure, message, "Errore", "Icon", "error");
        end

        function showInfo(obj, message)
            uialert(obj.Figure, message, "Info", "Icon", "info");
        end
    end

end