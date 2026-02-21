classdef TabController < Component
    %TABCONTROLLER Controller per la gestione delle schede
    %   Coordina le schede dell'interfaccia utente e applica le impostazioni

    properties
        App(:, 1)
    end

    properties ( GetAccess = public, SetAccess = private )
        TabRisultati(:, 1)
        Tabs containers.Map
        GruppoTab(:, 1)
    end

    properties ( Access = private )
        Listener(:, 1) event.listener {mustBeScalarOrEmpty}
    end

    methods
        function obj = TabController( namedArgs )
            %TABCONTROLLER Costruisce un'istanza di questa classe
            %   Inizializza il controller delle schede

            arguments ( Input )
                namedArgs.?TabController
            end % arguments ( Input )

            % Chiama il costruttore della superclasse.
            obj@Component()

            obj.Tabs = containers.Map();

            % Imposta le proprietà specificate dall'utente.
            set( obj, namedArgs )

        end

        function set.App( obj, app )
            obj.App = app;
            % Update existing tabs
            if ~isempty(obj.Tabs)
                keys = obj.Tabs.keys;
                for i = 1:length(keys)
                    obj.Tabs(keys{i}).App = app;
                end
            end

            if ~isempty(obj.TabRisultati)
                obj.TabRisultati.App = app;
            end

            if isempty(obj.Listener)
                obj.Listener = addlistener(obj.App.Modello, 'DataChanged', @obj.onDataChanged);
            end
        end

        function loadTabs(obj, tabConfigs)
            %LOADTABS Genera le tab dinamicamente dalla configurazione

            % Rimuovi le tab dinamiche esistenti
            if ~isempty(obj.Tabs)
                keys = obj.Tabs.keys;
                for i = 1:length(keys)
                    tabComp = obj.Tabs(keys{i});
                    % Elimina il contenitore uitab (parent del component)
                    delete(tabComp.Parent);
                    delete(tabComp);
                end
                remove(obj.Tabs, keys);
            end

            % Crea le nuove tab
            for i = 1:length(tabConfigs)
                conf = tabConfigs{i};
                t = [];

                try
                    % Crea uitab prima della tab risultati
                    t = uitab(obj.GruppoTab, "Title", conf.name);

                    % Crea DynamicTab
                    % FIX: Refactored DynamicTab constructor
                    dt = DynamicTab(t, conf);

                    if ~isempty(obj.App)
                        dt.App = obj.App;
                        dt.Subscribe();
                    end

                    % Salva nella mappa
                    if isfield(conf, 'id')
                        obj.Tabs(conf.id) = dt;
                    end
                catch ME
                    if ~isempty(t) && isvalid(t)
                        delete(t);
                    end

                    if ~isempty(obj.App)
                        obj.App.showError("Errore durante la creazione della tab '" + conf.name + "': " + ME.message);
                    else
                        rethrow(ME);
                    end
                end
            end

            % Assicura che TabRisultati sia l'ultima
            children = obj.GruppoTab.Children;
            resTab = obj.TabRisultati.Parent;
            if children(end) ~= resTab
                % Reorder
                otherTabs = children(children ~= resTab);
                obj.GruppoTab.Children = [otherTabs; resTab];
            end

            % Seleziona la prima tab
            if ~isempty(obj.GruppoTab.Children)
                obj.GruppoTab.SelectedTab = obj.GruppoTab.Children(1);
            end
        end

        function applySettings(obj, defaults)
            if isempty(defaults)
                return;
            end

            for i = 1:length(defaults)
                setting = defaults{i};
                try
                    if isfield(setting, 'id')
                        tabId = setting.id;
                        if isKey(obj.Tabs, tabId)
                            tabObj = obj.Tabs(tabId);
                            tabObj.applySettings(setting);
                        end
                    end
                catch ME
                    if ~isempty(obj.App)
                        obj.App.showError("Errore durante l'applicazione delle impostazioni: " + ME.message);
                    end
                end
            end
        end

        function tab = getTab(obj, id)
            if isKey(obj.Tabs, id)
                tab = obj.Tabs(id);
            else
                tab = [];
            end
        end
    end

    methods ( Access = protected )

        function setup ( obj )
            grid = uigridlayout(obj);
            grid.RowHeight = "1x";
            grid.ColumnWidth = "1x";
            grid.Padding = 0;
            obj.GruppoTab = uitabgroup(grid, "Position", [0,0,1,1]);

            risultatiTabContainer = uitab(obj.GruppoTab, "Title", "Risultati");
            % FIX: Refactored ResultTab constructor
            obj.TabRisultati = ResultTab(risultatiTabContainer);
        end

        function update( ~ )
        end % update

    end

    methods ( Access = private )
        function onDataChanged(obj, ~, ~)
            % obj.TabRisultati.Parent is the uitab
            obj.GruppoTab.SelectedTab = obj.TabRisultati.Parent;
            drawnow;
            obj.TabRisultati.update();
        end
    end
end