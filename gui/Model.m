classdef Model < handle
    %MODEL Application data model.

    % Copyright 2021-2025 The MathWorks, Inc.

    properties
        App(:, 1)
        Simulazione(:, 1)
        Config
        CSVFile
        ResultText
        ResultTextInterpreter
        CurrentExercise string {mustBeScalarOrEmpty}
    end

    properties ( SetAccess = private )
        % Application data.
        Data(:, 1) double = double.empty( 0, 1 )
    end % properties ( SetAccess = private )

    events ( NotifyAccess = private )
        % Event broadcast when the data is changed.
        DataChanged
    end % events ( NotifyAccess = private )

    methods

        function obj = Model()
            addpath('./utility');
            obj.Config = YamlParser.read(fullfile(fileparts(mfilename('fullpath')), 'config/config.yaml'));

            if ~isempty(obj.Config) && iscell(obj.Config) && isfield(obj.Config{1}, 'exercise')
                obj.CurrentExercise = obj.Config{1}.exercise;
            end
            obj.ResultTextInterpreter = 'none';
        end

        function simulate( obj )
            %SIMULATE Esegue una simulazione basata sul tipo selezionato.

            %% Configurazione Specifica
            currentConfig = [];
            for i = 1:numel(obj.Config)
                if strcmp(obj.Config{i}.exercise, obj.CurrentExercise)
                    currentConfig = obj.Config{i};
                    break;
                end
            end

            if isempty(currentConfig)
                obj.App.showError("Configurazione non trovata per l'esercizio selezionato.");
                return;
            end

            %% Inputs dinamici
            if isfield(currentConfig, 'inputs')
                inputs = currentConfig.inputs;
                for i = 1:numel(inputs)
                    inputConfig = inputs{i};
                    try
                        tabObj = obj.App.TabController.getTab(inputConfig.tab);
                        compObj = tabObj.getComponent(inputConfig.component);
                        % Assegna variabile nel workspace corrente
                        eval([inputConfig.name, ' = compObj.Value;']);
                    catch ME
                        fprintf('WARNING: Impossibile caricare l''input %s dalla tab %s, componente %s\n', inputConfig.name, inputConfig.tab, inputConfig.component);
                    end
                end
            end

            %% Pipeline
            pipeline = currentConfig.pipeline;
            for j = 1:length(pipeline)
                cmd = pipeline{j};
                try
                    cmd = regexprep(cmd, '\<return\>', 'error(''App:PipelineReturn'', ''Return'')');
                    eval(cmd);
                catch ME
                    if strcmp(ME.identifier, 'App:PipelineReturn')
                        return;
                    end
                    fprintf("Error executing pipeline command: %s\nError: %s\n", cmd, ME.message);
                    obj.App.showError("Pipeline Error: " + ME.message + newline + "Command: " + cmd);
                    rethrow(ME);
                end
            end

            %% Risultato (testuale)
            if isfield(currentConfig, 'resultText')
                resultText = currentConfig.resultText;
                try
                    obj.ResultText = eval(resultText);
                catch ME
                    fprintf('Errore nella valutazione del testo "%s": %s\n', resultText, ME.message);
                    obj.App.showError("Result-text Error: " + ME.message + newline + "Command: " + cmd);
                    return;
                end
                if isfield(currentConfig, 'resultTextInterpreter')
                    interpreter = currentConfig.resultTextInterpreter;
                    obj.ResultTextInterpreter = interpreter;
                else
                    obj.ResultTextInterpreter = 'none';
                end

                obj.ResultText = replace(obj.ResultText, '\n', newline);
                obj.ResultText = replace(obj.ResultText, '\t', '    ');

            else
                obj.ResultText = 'Nessun risultato prodotto.';
                obj.ResultTextInterpreter = 'none';
            end


            %% Esecuzione comandi di drawing per i plots
            if isfield(currentConfig, 'plots')
                plots = currentConfig.plots;
                validPlots = {};

                % Filtra i plots in base alle regole
                for i = 1:numel(plots)
                    plotConfig = plots{i};
                    isValid = true;

                    if isfield(plotConfig, 'rules')
                        rules = plotConfig.rules;
                        for k = 1:numel(rules)
                            rule = rules{k};
                            % Valuta la regola nel workspace corrente
                            try
                                ruleResult = eval(rule);
                                if ~ruleResult
                                    isValid = false;
                                    break;
                                end
                            catch ME
                                fprintf('Errore nella valutazione della regola "%s": %s\n', rule, ME.message);
                                isValid = false;
                                break;
                            end
                        end
                    end

                    if isValid
                        validPlots{end+1} = plotConfig;
                    end
                end

                % Aggiorna le tabs nella view con i plots filtrati
                obj.App.VistaGrafici.setupTabs(validPlots);

                % Disegna i plots validi
                for i = 1:numel(validPlots)
                    plotConfig = validPlots{i};

                    drawingCommands = plotConfig.drawing;

                    % Crea una figura tradizionale temporanea invisibile
                    % Questo è necessario perché stampaGrafici usa subplot che lavora su figure
                    tempFig = figure('Visible', 'off');

                    % Esegui ogni comando di drawing
                    for j = 1:numel(drawingCommands)
                        cmd = drawingCommands{j};
                        % Valuta il comando nel workspace corrente
                        try
                            eval(cmd);
                        catch ME
                            fprintf('Errore nella valutazione del comando (plotting)"%s": %s\n', cmd, ME.message);
                            obj.App.showError("Plotting Error: " + ME.message + newline + "Command: " + cmd);
                            rethrow(ME); % Removed to prevent app crash
                        end

                        % Aggiungi hold on tra i comandi per sovrapporre i grafici
                        if j < numel(drawingCommands)
                            hold on;
                        end
                    end

                    % Aggiorna la tab corrispondente usando il metodo di PlotView
                    obj.App.VistaGrafici.updatePlot(i, tempFig.Children);

                    % Chiudi la figura temporanea
                    close(tempFig);
                end

            end

            notify( obj, "DataChanged" )

        end % simulate

    end % methods

end % classdef