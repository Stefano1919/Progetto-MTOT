classdef PlotView < Component
    %VIEW Visualizes the data, responding to any relevant model events.

    % Copyright 2021-2025 The MathWorks, Inc.

    properties
        App(:,1) App
    end % properties

    properties ( SetAccess = private )
        TabGroup(:, 1) matlab.ui.container.TabGroup {mustBeScalarOrEmpty}
        Tabs(:, 1) cell = {}
        Panel(:, 1) matlab.ui.container.Panel {mustBeScalarOrEmpty}
        MessageLabel(:, 1) matlab.ui.control.Label {mustBeScalarOrEmpty}
    end % properties ( SetAccess = private )

    properties ( Access = private )
        % Listener object used to respond dynamically to model events.
        Listener(:, 1) event.listener {mustBeScalarOrEmpty}
    end % properties ( Access = private )

    methods

        function Subscribe( obj )
            % Create weak reference to avoid circular reference
            weakObj = matlab.lang.WeakReference( obj );

            obj.Listener = listener( obj.App.Modello, ...
                "DataChanged", ...
                @( s, e ) weakObj.Handle.onDataChanged( s, e ) );

            % Inizializza le tabs con l'esercizio attualmente selezionato (in modalità reset)
            if ~isempty(obj.App.Controller) && ~isempty(obj.App.Controller.DropDownMenu)
                currentExercise = obj.App.Controller.DropDownMenu.Value;
                obj.resetView(currentExercise);
            end

            % Refresh the view.
            onDataChanged( obj, [], [] )

        end

        function resetView(obj, ~)
            %RESETVIEW Resetta la vista mostrando il messaggio di attesa e nascondendo i grafici

            % Pulisci le tab esistenti
            delete(obj.TabGroup.Children);
            obj.Tabs = {};

            % Gestione visibilità
            obj.TabGroup.Visible = 'off';
            obj.MessageLabel.Visible = 'on';
        end

        function updatePlot(obj, index, figureChildren)
            %UPDATEPLOT Updates the specified tab with new plot content.

            if index > numel(obj.Tabs) || index < 1
                return;
            end

            currentTab = obj.Tabs{index};

            % Pulisci la tab prima di disegnare
            delete(currentTab.Children);

            % Copia il contenuto della figura temporanea nella tab
            try
                copyobj(figureChildren, currentTab);
            catch ME
                if ~isempty(obj.App)
                    obj.App.showError("Errore durante l'aggiornamento del grafico: " + ME.message);
                end
            end
        end

        function obj = PlotView( namedArgs )
            %VIEW View constructor.

            arguments ( Input )
                namedArgs.?PlotView
            end % arguments ( Input )

            % Call the superclass constructor.
            obj@Component()

            % Set any user-specified properties.
            set( obj, namedArgs )

        end % constructor

        function setupTabs( obj, plots )
            %SETUPTABS Crea dinamicamente le tabs basandosi sulla configurazione passata

            % Gestione visibilità: Nascondi messaggio, mostra tabs
            obj.MessageLabel.Visible = 'off';
            obj.TabGroup.Visible = 'on';

            % Pulisci le tab esistenti
            delete(obj.TabGroup.Children);
            obj.Tabs = {};

            % Crea una tab per ciascun elemento in plots
            for i = 1:numel(plots)
                plotConfig = plots{i};
                tab = [];

                try
                    % Crea la tab con il nome specificato
                    tab = uitab(obj.TabGroup, "Title", plotConfig.name);
                    obj.Tabs{end+1} = tab;
                catch ME
                    if ~isempty(tab) && isvalid(tab)
                        delete(tab);
                    end

                    if ~isempty(obj.App)
                        obj.App.showError("Errore nel setup della tab grafico '" + plotConfig.name + "': " + ME.message);
                    end
                end
            end

        end % setupTabs

    end % methods

    methods ( Access = protected )

        function setup( obj )
            %SETUP Initialize the view.

            % Create a grid layout to manage the resizing of the component
            grid = uigridlayout(obj);
            grid.RowHeight = "1x";
            grid.ColumnWidth = "1x";
            grid.Padding = 0;
            grid.Scrollable = 'on';

            % Crea il panel con bordo arrotondato
            obj.Panel = uipanel( ...
                "Parent", grid, ... % Parent to the grid
                "BorderType", "line", ...
                "BorderWidth", 2, ...
                "BackgroundColor", [1 1 1]);

            % Set layout properties for the panel
            obj.Panel.Layout.Row = 1;
            obj.Panel.Layout.Column = 1;

            % Crea il TabGroup all'interno del panel
            obj.TabGroup = uitabgroup(obj.Panel, ...
                "Units", "normalized", ...
                "Position", [0 0 1 1], ...
                "Visible", "off");

            % Crea la label di messaggio
            obj.MessageLabel = uilabel(obj.Panel);
            obj.MessageLabel.HorizontalAlignment = 'center';
            obj.MessageLabel.VerticalAlignment = 'center';
            obj.MessageLabel.Position = [0 0 1 1];

            % Refactoring per usare Grid Layout nel Panel per centrare la label
            obj.Panel.AutoResizeChildren = 'off'; % Disabilita gestione automatica che potrebbe confliggere

            % Layout Manager per il Panel
            panelLayout = uigridlayout(obj.Panel);
            panelLayout.ColumnWidth = {'1x'};
            panelLayout.RowHeight = {'1x'};
            panelLayout.Padding = 0;

            % Ricollega TabGroup al layout
            obj.TabGroup.Parent = panelLayout;
            obj.TabGroup.Layout.Row = 1;
            obj.TabGroup.Layout.Column = 1;

            % Ricollega MessageLabel al layout
            obj.MessageLabel.Parent = panelLayout;
            obj.MessageLabel.Layout.Row = 1;
            obj.MessageLabel.Layout.Column = 1;
            obj.MessageLabel.Text = 'Effettuare una simulazione per visualizzare i grafici';
            obj.MessageLabel.FontSize = 14;
            obj.MessageLabel.FontColor = [0.5 0.5 0.5];
            obj.MessageLabel.Visible = 'on';

        end % setup

        function update( obj )
            %UPDATE Update the view in response to changes in the public
            %properties.



        end % update

    end % methods ( Access = protected )

    methods ( Access = private )

        function onDataChanged( obj, ~, ~ )
            %ONDATACHANGED Listener callback, responding to the model event
            %"DataChanged".

            % I comandi di drawing vengono eseguiti in Model.simulate
            % dove tutte le variabili sono disponibili

        end % onDataChanged

    end % methods ( Access = private )

end % classdef