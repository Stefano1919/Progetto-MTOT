classdef DynamicTab < handle
    %DYNAMICTAB Una scheda che genera il suo contenuto dalla configurazione.

    properties
        App(:, 1) App {mustBeScalarOrEmpty}
        Components containers.Map
        ComponentLabels containers.Map
        Grid matlab.ui.container.GridLayout
        VisibilityRules containers.Map
        LabelRules containers.Map
        EnableRules containers.Map
        Config
        Parent(:, 1) matlab.ui.container.Tab {mustBeScalarOrEmpty}
    end

    properties ( Access = private )
        Listener event.listener {mustBeScalarOrEmpty}
        ButtonPushedListener event.listener {mustBeScalarOrEmpty}
        ButtonReleasedListener event.listener {mustBeScalarOrEmpty}
    end % properties ( Access = private )

    methods
        function obj = DynamicTab(parent, config)
            obj.Parent = parent;
            obj.Components = containers.Map();
            obj.ComponentLabels = containers.Map();
            obj.VisibilityRules = containers.Map();
            obj.LabelRules = containers.Map();
            obj.EnableRules = containers.Map();

            % Create grid directly on the parent (uitab)
            obj.Grid = uigridlayout("Parent", parent, ...
                "ColumnWidth", {'fit', '1x', 'fit'}, ...
                "RowHeight", {'fit'}, ...
                "Scrollable", "on");

            obj.Config = config;
        end

        function set.Config(obj, config)
            obj.Config = config;
            obj.build();
        end


        function Subscribe( obj )
            if ~isempty(obj.App) && ~isempty(obj.App.Controller)
                obj.ButtonPushedListener = listener( obj.App.Controller, ...
                    "ButtonPushed", ...
                    @obj.onButtonPushed );
                obj.ButtonReleasedListener = listener( obj.App.Controller, ...
                    "ButtonReleased", ...
                    @obj.onButtonReleased );
            end
        end

        function onButtonPushed(obj, ~, ~)
            if ~isempty(obj.Components)
                comps = values(obj.Components);
                for k = 1:length(comps)
                    comps{k}.Enable = 'off';
                end
            end
        end

        function onButtonReleased(obj, ~, ~)
            if ~isempty(obj.Components)
                comps = values(obj.Components);
                for k = 1:length(comps)
                    comps{k}.Enable = 'on';
                end
            end
            obj.checkEnable();
        end

        function applySettings(obj, settings)
            if isempty(settings)
                return;
            end

            if isfield(settings, 'values')
                vals = settings.values;
                fields = fieldnames(vals);
                for i = 1:length(fields)
                    compId = fields{i};
                    val = vals.(compId);

                    if isKey(obj.Components, compId)
                        comp = obj.Components(compId);
                        try
                            comp.Value = val;
                        catch ME
                            if ~isempty(obj.App)
                                uialert(obj.App.Figure, ["Errore nell'impostare il valore per " + compId, ME.message], "Errore");
                            end
                        end
                    end
                end
            end

            if isfield(settings, 'disabled')
                disabledIds = settings.disabled; % Cell array of strings
                if iscell(disabledIds)
                    for i = 1:length(disabledIds)
                        compId = disabledIds{i};
                        if isKey(obj.Components, compId)
                            comp = obj.Components(compId);
                            comp.Enable = 'off';
                        end
                    end
                end
            end

            % Ricontrolla visibilità ed etichette dopo aver applicato le impostazioni
            obj.checkVisibility();
            obj.updateLabels();
            obj.checkEnable();
        end

        function comp = getComponent(obj, id)
            if isKey(obj.Components, id)
                comp = obj.Components(id);
            else
                comp = [];
            end
        end

        function runCallback(obj, command)
            eval(command);
        end
    end

    methods (Access = private)
        function build(obj)
            %BUILD Crea componenti basati sulla configurazione

            config = obj.Config;

            if isempty(config)
                return;
            end

            if isfield(config, 'components')
                componentsConfig = config.components;
            else
                return;
            end

            % Pulisci i componenti esistenti
            if ~isempty(obj.Components)
                remove(obj.Components, obj.Components.keys);
            end
            if ~isempty(obj.ComponentLabels)
                remove(obj.ComponentLabels, obj.ComponentLabels.keys);
            end
            if ~isempty(obj.VisibilityRules)
                remove(obj.VisibilityRules, obj.VisibilityRules.keys);
            end
            if ~isempty(obj.LabelRules)
                remove(obj.LabelRules, obj.LabelRules.keys);
            end
            if ~isempty(obj.EnableRules)
                remove(obj.EnableRules, obj.EnableRules.keys);
            end

            % Pulisci i figli della griglia (ma non la griglia stessa)
            if ~isempty(obj.Grid.Children)
                delete(obj.Grid.Children);
            end

            numComponents = length(componentsConfig);

            % Riconfigura la griglia principale
            obj.Grid.ColumnWidth = {'fit', '1x', 'fit'};
            % Usa righe ad altezza fissa per garantire l'allineamento in alto
            obj.Grid.RowHeight = repmat({'fit'}, 1, numComponents);

            for i = 1:numComponents
                compDef = componentsConfig{i};
                row = i;
                currentLabels = [];

                % 1. Gestisci etichetta sinistra
                hasLeftLabel = false;
                if isfield(compDef, 'labels')
                    for j = 1:length(compDef.labels)
                        lblDef = compDef.labels{j};
                        if strcmp(lblDef.position, 'left')
                            l = uilabel("Parent", obj.Grid, "Text", lblDef.text);
                            if isfield(lblDef, 'interpreter')
                                l.Interpreter = lblDef.interpreter;
                            else
                                l.Interpreter = 'none';
                            end
                            l.UserData = struct('DefaultText', lblDef.text);
                            if isfield(lblDef, 'rules')
                                l.UserData.Rules = lblDef.rules;
                                obj.LabelRules(compDef.id) = true;
                            end
                            currentLabels = [currentLabels, l];
                            l.Layout.Row = row;
                            l.Layout.Column = 1;
                            hasLeftLabel = true;
                        end
                    end
                end

                % 2. Crea componente
                if isfield(compDef, 'kind')
                    try
                        % Crea istanza usando il nome della classe
                        compClass = compDef.kind;

                        % Usare feval con il nome della classe funziona se è nel percorso
                        newComp = feval(compClass, "Parent", obj.Grid);

                        % Imposta ID/Tag se disponibile
                        if isfield(compDef, 'id')
                            % Memorizza nella mappa
                            obj.Components(compDef.id) = newComp;
                            newComp.Tag = compDef.id; % Memorizza ID nel Tag per ricerca inversa
                        end

                        % Imposta altre proprietà
                        fields = fieldnames(compDef);
                        for k = 1:length(fields)
                            propName = fields{k};
                            % Salta meta-proprietà
                            if strcmp(propName, 'kind') || strcmp(propName, 'id') || ...
                                    strcmp(propName, 'labels') || strcmp(propName, 'visible_when') || ...
                                    strcmp(propName, 'disabled_when') || strcmp(propName, 'disable_when')
                                continue;
                            end

                            val = compDef.(propName);

                            % Mappatura alias comuni
                            targetProp = propName;
                            if strcmp(propName, 'options')
                                targetProp = 'Items';
                            elseif strcmp(propName, 'limits')
                                targetProp = 'Limits';
                            elseif strcmp(propName, 'step')
                                targetProp = 'Step';
                            elseif strcmp(propName, 'value')
                                targetProp = 'Value';
                            end

                            if strcmp(propName, 'ButtonPushedFcn')
                                newComp.ButtonPushedFcn = @(src, event) obj.runCallback(val);
                                continue;
                            end

                            try
                                newComp.(targetProp) = val;
                            catch ME
                                fprintf('Warning: Failed to set property "%s" on component "%s". Error: %s\n', targetProp, compDef.id, ME.message);
                            end
                        end

                        % Layout
                        newComp.Layout.Row = row;
                        hasRightLabel = false;

                        % Controlla etichetta destra per determinare l'estensione della colonna
                        if isfield(compDef, 'labels')
                            for j = 1:length(compDef.labels)
                                lblDef = compDef.labels{j};
                                if strcmp(lblDef.position, 'right')
                                    hasRightLabel = true;
                                end
                            end
                        end

                        if hasLeftLabel
                            if hasRightLabel
                                newComp.Layout.Column = 2;
                            else
                                newComp.Layout.Column = [2 3];
                            end
                        else
                            if hasRightLabel
                                newComp.Layout.Column = [1 2];
                            else
                                newComp.Layout.Column = [1 3];
                            end
                        end

                        % 3. Gestisci etichetta destra
                        if hasRightLabel
                            for j = 1:length(compDef.labels)
                                lblDef = compDef.labels{j};
                                if strcmp(lblDef.position, 'right')
                                    l = uilabel("Parent", obj.Grid, "Text", lblDef.text);
                                    if isfield(lblDef, 'interpreter')
                                        l.Interpreter = lblDef.interpreter;
                                    else
                                        l.Interpreter = 'none';
                                    end
                                    l.UserData = struct('DefaultText', lblDef.text);
                                    if isfield(lblDef, 'rules')
                                        l.UserData.Rules = lblDef.rules;
                                        obj.LabelRules(compDef.id) = true;
                                    end
                                    currentLabels = [currentLabels, l];
                                    l.Layout.Row = row;
                                    l.Layout.Column = 3;
                                end
                            end
                        end

                        % 4. Gestisci regole di visibilità
                        if isfield(compDef, 'visible_when')
                            obj.VisibilityRules(compDef.id) = compDef.visible_when;
                        end

                        if isfield(compDef, 'disable_when')
                            obj.EnableRules(compDef.id) = compDef.disable_when;
                        elseif isfield(compDef, 'disabled_when')
                            obj.EnableRules(compDef.id) = compDef.disabled_when;
                        end

                        % Aggiungi ValueChangedFcn per attivare aggiornamenti
                        % Lo aggiungiamo a tutto ciò che lo possiede
                        if isprop(newComp, 'ValueChangedFcn')
                            newComp.ValueChangedFcn = @obj.onValueChanged;
                        end

                    catch ME
                        % Fallback o segnalazione errori
                        uialert(obj.App.Figure, ["Error creating component: " + compDef.kind, ME.message], "Error");
                    end
                end

                if isfield(compDef, 'id')
                    obj.ComponentLabels(compDef.id) = currentLabels;
                end
            end

            % Controllo iniziale visibilità ed etichette
            obj.checkVisibility();
            obj.updateLabels();
            obj.checkEnable();
        end

        function onValueChanged(obj, ~, ~)
            obj.checkVisibility();
            obj.updateLabels();
            obj.checkEnable();
        end

        function checkVisibility(obj)
            if isempty(obj.VisibilityRules)
                return;
            end

            keys = obj.VisibilityRules.keys;
            for i = 1:length(keys)
                targetId = keys{i};
                rule = obj.VisibilityRules(targetId);

                if isKey(obj.Components, targetId)
                    targetComp = obj.Components(targetId);

                    % Controlla regola
                    isVisible = true;
                    if isfield(rule, 'id') && isfield(rule, 'value')
                        triggerId = rule.id;
                        expectedValue = rule.value;

                        if isKey(obj.Components, triggerId)
                            triggerComp = obj.Components(triggerId);
                            actualValue = triggerComp.Value;

                            % Semplice controllo di uguaglianza
                            if ~isequal(actualValue, expectedValue)
                                isVisible = false;
                            end
                        end
                    end

                    % Applica visibilità e aggiorna layout griglia
                    if isVisible
                        targetComp.Visible = 'on';
                        lblVis = 'on';
                        rowHeight = 'fit';
                    else
                        targetComp.Visible = 'off';
                        lblVis = 'off';
                        rowHeight = 0; % Collassa la riga
                    end

                    % Aggiorna l'altezza della riga nella griglia
                    if isprop(targetComp, 'Layout') && isprop(targetComp.Layout, 'Row')
                        rowIdx = targetComp.Layout.Row;
                        % Verifica che l'indice di riga sia valido
                        if ~isempty(rowIdx) && rowIdx > 0 && rowIdx <= length(obj.Grid.RowHeight)
                            obj.Grid.RowHeight{rowIdx} = rowHeight;
                        end
                    end

                    if isKey(obj.ComponentLabels, targetId)
                        lbls = obj.ComponentLabels(targetId);
                        for k=1:length(lbls)
                            lbls(k).Visible = lblVis;
                        end
                    end
                end
            end
        end

        function checkEnable(obj)
            if isempty(obj.EnableRules)
                return;
            end

            keys = obj.EnableRules.keys;
            for i = 1:length(keys)
                targetId = keys{i};
                rule = obj.EnableRules(targetId);

                if isKey(obj.Components, targetId)
                    targetComp = obj.Components(targetId);

                    shouldDisable = false;
                    if isfield(rule, 'id') && isfield(rule, 'value')
                        triggerId = rule.id;
                        expectedValue = rule.value;

                        if isKey(obj.Components, triggerId)
                            triggerComp = obj.Components(triggerId);
                            actualValue = triggerComp.Value;

                            if isequal(actualValue, expectedValue)
                                shouldDisable = true;
                            end
                        end
                    end

                    if shouldDisable
                        targetComp.Enable = 'off';
                    else
                        targetComp.Enable = 'on';
                    end
                end
            end
        end

        function updateLabels(obj)
            if isempty(obj.LabelRules)
                return;
            end

            % Itera sui componenti che hanno regole per le etichette
            keys = obj.LabelRules.keys;
            for i = 1:length(keys)
                compId = keys{i};
                if isKey(obj.ComponentLabels, compId)
                    lbls = obj.ComponentLabels(compId);
                    for j = 1:length(lbls)
                        lbl = lbls(j);
                        if isstruct(lbl.UserData) && isfield(lbl.UserData, 'Rules')
                            rules = lbl.UserData.Rules;
                            newText = lbl.UserData.DefaultText;

                            % Controlla regole
                            for k = 1:length(rules)
                                rule = rules{k};
                                if isfield(rule, 'id') && isfield(rule, 'value') && isfield(rule, 'text')
                                    triggerId = rule.id;
                                    triggerVal = rule.value;

                                    if isKey(obj.Components, triggerId)
                                        triggerComp = obj.Components(triggerId);
                                        if isequal(triggerComp.Value, triggerVal)
                                            newText = rule.text;
                                        end
                                    end
                                end
                            end

                            lbl.Text = newText;
                        end
                    end
                end
            end
        end
    end
end
