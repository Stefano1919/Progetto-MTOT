classdef Controller < Component
    %CONTROLLER Fornisce un controllo interattivo per generare nuovi dati.

    % Copyright 2021-2025 The MathWorks, Inc.

    properties ( GetAccess = public, SetAccess = private )
        Button(:, 1) matlab.ui.control.Button {mustBeScalarOrEmpty}
        DropDownMenu(:, 1) matlab.ui.control.DropDown {mustBeScalarOrEmpty}
        Image(:, 1)
        TabController(:, 1)
        Grid(:, 1) matlab.ui.container.GridLayout {mustBeScalarOrEmpty}
    end

    properties
        App(:, 1) App {mustBeScalarOrEmpty}
    end

    events ( NotifyAccess = private )
        % Event broadcast when the data is changed.
        ButtonPushed
        ButtonReleased
        ExerciseChanged
    end

    methods

        function obj = Controller( namedArgs )
            % CONTROLLER Costruttore del Controller.

            arguments ( Input )
                namedArgs.?Controller
            end % arguments ( Input )

            % Chiama il costruttore della superclasse.
            obj@Component()

            % Imposta le proprietà specificate dall'utente.
            set( obj, namedArgs )

        end % constructor

        function set.App( obj, app )
            obj.App = app;
            obj.TabController = obj.App.TabController;
            obj.Image = uiimage(obj.Grid);
            obj.Image.Layout.Row = 2;
            obj.Image.Layout.Column = 1;

            obj.TabController.Parent = obj.Grid;
            obj.TabController.Layout.Row = 3;
            obj.TabController.Layout.Column = 1;

            obj.Button = uibutton( ...
                "Parent", obj.Grid, ...
                "Text", "Simula", ...
                "ButtonPushedFcn", @obj.onButtonPushed);
            obj.Button.Layout.Row = 4;
            obj.Button.Layout.Column = 1;

            % Popola il menu a discesa dalla configurazione
            config = obj.App.Modello.Config;
            if ~isempty(config) && iscell(config)
                exercises = strings(0);
                for i = 1:length(config)
                    item = config{i};
                    if isfield(item, 'exercise')
                        exercises(end+1) = string(item.exercise);
                    end
                end

                if ~isempty(exercises)
                    obj.DropDownMenu.Items = exercises;
                    obj.DropDownMenu.Value = exercises(1);
                    obj.applySimulationConfig(exercises(1));
                end
            end
        end

        function onButtonPushed( obj, ~, ~ )
            % Imposta lo stato di caricamento
            notify(obj, "ButtonPushed");
            obj.Button.Text = "Simulazione...";
            obj.Button.Enable = "off";
            obj.DropDownMenu.Enable = "off";
            drawnow;

            modello = obj.App.Modello;
            try
                modello.simulate();
            catch ME
                % if ~isempty(obj.App)
                %     obj.App.showError("Errore imprevisto durante la simulazione: " + ME.message);
                % end
                obj.Button.Text = "Simula";
                obj.Button.Enable = "on";
                obj.DropDownMenu.Enable = "on";
                notify(obj, "ButtonReleased");
                rethrow(ME);
            end

            % Ripristina lo stato del pulsante
            obj.Button.Text = "Simula";
            obj.Button.Enable = "on";
            obj.DropDownMenu.Enable = "on";
            notify(obj, "ButtonReleased");
        end % onButtonPushed

    end % methods

    methods ( Access = protected )

        function setup( obj )
            %SETUP Inizializza il controller.
            % Crea la griglia e il pulsante.
            obj.Grid = uigridlayout( ...
                "Parent", obj, ...
                "RowHeight", {"0.05x", "0.5x", "0.5x", "0.05x"}, ...
                "ColumnWidth", "1x", ...
                "Padding", 0);

            tipologiaSimulazionePanel = uigridlayout( ...
                "Parent", obj.Grid, ...
                "RowHeight", "1x", ...
                "ColumnWidth", "1x", ...
                "Padding", 0);
            tipologiaSimulazionePanel.Layout.Row = 1;
            tipologiaSimulazionePanel.Layout.Column = 1;

            obj.DropDownMenu = uidropdown(tipologiaSimulazionePanel, "ValueChangedFcn", @obj.onSimulationChanged);


        end % setup

        function update( ~ )
        end % update

    end % methods ( Access = protected )

    methods ( Access = private )

        function onSimulationChanged( obj, ~, ~ )
            selected = obj.DropDownMenu.Value;
            obj.applySimulationConfig(selected);
            notify(obj, "ExerciseChanged")
        end

        function applySimulationConfig(obj, exercise)
            if isempty(obj.App)
                return;
            end

            config = obj.App.Modello.Config;
            imageName = "";
            defaults = [];
            settings = [];

            for i = 1:length(config)
                if strcmp(config{i}.exercise, exercise)
                    if isfield(config{i}, 'image')
                        imageName = config{i}.image;
                    end
                    if isfield(config{i}, 'defaults')
                        defaults = config{i}.defaults;
                    end
                    if isfield(config{i}, 'settings')
                        settings = config{i}.settings;
                    end
                    break;
                end
            end

            if imageName ~= ""
                imagePath = fullfile(fileparts(mfilename('fullpath')), 'assets', imageName);
                obj.Image.ImageSource = imagePath;
            end

            obj.TabController.loadTabs(settings);
            obj.TabController.applySettings(defaults);

            % Aggiorna l'esercizio corrente nel modello
            obj.App.Modello.CurrentExercise = exercise;

            % Aggiorna le tabs dei grafici se la vista è disponibile
            if ~isempty(obj.App.VistaGrafici)
                obj.App.VistaGrafici.resetView(exercise);
            end
        end

    end % methods ( Access = private )

end % classdef