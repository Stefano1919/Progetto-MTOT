classdef ResultTab < handle
    %ResultTab Vista per la visualizzazione dei risultati.

    properties
        App(:, 1) App {mustBeScalarOrEmpty}
    end

    properties ( GetAccess = public, SetAccess = private )
        EtichettaRisultato(:, 1) matlab.ui.control.Label {mustBeScalarOrEmpty}
        Griglia(:, 1) matlab.ui.container.GridLayout {mustBeScalarOrEmpty}
        Parent(:, 1) matlab.ui.container.Tab {mustBeScalarOrEmpty}
    end

    properties ( Access = private )
        DataListener(:, 1) event.listener {mustBeScalarOrEmpty}
        ExerciseListener event.listener {mustBeScalarOrEmpty}
        ButtonPushedListener event.listener {mustBeScalarOrEmpty}
    end % properties ( Access = private )


    methods
        function Subscribe( obj )
            if ~isempty(obj.App) && ~isempty(obj.App.Modello)
                obj.DataListener = listener( obj.App.Modello, ...
                    "DataChanged", ...
                    @obj.onDataChanged );

                obj.ExerciseListener = listener( obj.App.Controller, ...
                    "ExerciseChanged", ...
                    @obj.onExerciseChanged );

                obj.ButtonPushedListener = listener( obj.App.Controller, ...
                    "ButtonPushed", ...
                    @obj.onExerciseChanged );

                onDataChanged( obj, [], [] )
                onExerciseChanged( obj, [], [] )
            end
        end

        function obj = ResultTab( parent )
            obj.Parent = parent;
            % Create grid directly on the parent (uitab)
            obj.Griglia = uigridlayout( "Parent", parent, ...
                "RowHeight", {'fit'}, ...
                "ColumnWidth", {'fit'}, ...
                "Scrollable", "on" );

            obj.EtichettaRisultato = uilabel( "Parent", obj.Griglia, ...
                "Text", "Nessun risultato prodotto.", ...
                "WordWrap", "on");
        end

        function set.App( obj, app )
            obj.App = app;
            obj.Subscribe();
        end
    end

    methods ( Access = public )
        function update( obj )
            if ~isempty(obj.App) && ~isempty(obj.App.Modello)
                if isempty(obj.App.Modello.ResultTextInterpreter)
                    obj.EtichettaRisultato.Interpreter = 'none';
                else
                    obj.EtichettaRisultato.Interpreter = obj.App.Modello.ResultTextInterpreter;
                end

                rawText = obj.App.Modello.ResultText;

                if isempty(rawText) || rawText == ""
                    obj.EtichettaRisultato.Text = "Nessun risultato prodotto.";
                else
                    obj.EtichettaRisultato.Text = rawText;
                end
                drawnow;
            end
        end

        function onDataChanged( obj, ~, ~ )
            obj.update();
        end % onDataChanged

        function onExerciseChanged( obj, ~, ~ )
            obj.EtichettaRisultato.Text = "Nessun risultato prodotto.";
        end

    end
end
