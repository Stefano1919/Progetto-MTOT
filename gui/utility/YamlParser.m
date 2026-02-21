classdef YamlParser
    %YAMLPARSER Un semplice parser YAML personalizzato per la configurazione dell'applicazione.

    methods (Static)
        function result = read(filePath)
            rawLines = readlines(filePath);
            % Filtra righe vuote e commenti
            lines = strings(0);
            for i = 1:length(rawLines)
                str = rawLines(i);
                trimmed = strtrim(str);
                if strlength(trimmed) > 0 && ~startsWith(trimmed, "#")
                    lines(end+1) = str;
                end
            end

            % Ottieni la directory del file corrente per risolvere i percorsi relativi
            [currentDir, ~, ~] = fileparts(filePath);
            if isempty(currentDir)
                currentDir = pwd;
            end

            [result, ~] = YamlParser.parseBlock(lines, currentDir);
        end
    end

    methods (Static, Access = private)
        function [result, remaining] = parseBlock(lines, currentDir)
            if isempty(lines)
                result = [];
                remaining = [];
                return;
            end

            firstLine = char(lines(1));
            indent = YamlParser.getIndent(firstLine);
            trimmed = strtrim(firstLine);

            if startsWith(trimmed, '-')
                % È una lista
                result = {};
                idx = 1;
                while idx <= length(lines)
                    line = char(lines(idx));
                    currIndent = YamlParser.getIndent(line);

                    if currIndent < indent
                        break; % Fine del blocco
                    end

                    trimmedLine = strtrim(line);
                    if startsWith(trimmedLine, '-')
                        % Inizio di un nuovo elemento

                        % Trova il blocco di righe per questo elemento
                        startIdx = idx;
                        idx = idx + 1;
                        while idx <= length(lines)
                            nextLine = char(lines(idx));
                            nextIndent = YamlParser.getIndent(nextLine);
                            % Se la riga successiva ha lo stesso indentamento e inizia con -, è l'elemento successivo
                            if nextIndent == indent && startsWith(strtrim(nextLine), '-')
                                break;
                            end
                            if nextIndent < indent
                                break;
                            end
                            idx = idx + 1;
                        end
                        itemBlockRaw = lines(startIdx:idx-1);

                        % Ora analizza questo blocco elemento
                        firstItemLine = char(itemBlockRaw(1));
                        % Rimuovi il "- "
                        dashPos = find(firstItemLine == '-', 1);
                        contentPos = dashPos + 1;
                        % Salta gli spazi dopo il trattino
                        while contentPos <= length(firstItemLine) && firstItemLine(contentPos) == ' '
                            contentPos = contentPos + 1;
                        end

                        if contentPos > length(firstItemLine)
                            firstContent = "";
                        else
                            firstContent = firstItemLine(contentPos:end);
                        end

                        if isempty(firstContent)
                            % Elemento definito nelle righe successive
                            [nestedRes, ~] = YamlParser.parseBlock(itemBlockRaw(2:end), currentDir);
                            result{end+1} = nestedRes;
                        elseif contains(firstContent, ':') && ~startsWith(firstContent, '"') && ~startsWith(firstContent, "'")
                            % Inizio mappa inline: "- chiave: valore"
                            % Costruiamo un nuovo blocco per la mappa
                            mapLines = strings(0);
                            mapLines(1) = string(firstContent); % "key: value"

                            % Aggiungi il resto delle righe, regolando l'indentazione
                            % Le allineiamo a partire da 0 relativo alla mappa
                            % Il contenuto iniziava a contentPos nella riga originale
                            % Quindi rimuoviamo (contentPos - 1) caratteri dalle righe successive

                            for k = 2:length(itemBlockRaw)
                                l = char(itemBlockRaw(k));
                                if length(l) >= contentPos
                                    mapLines(end+1) = string(l(contentPos:end));
                                else
                                    mapLines(end+1) = string(l);
                                end
                            end

                            [nestedRes, ~] = YamlParser.parseBlock(mapLines, currentDir);
                            result{end+1} = nestedRes;
                        else
                            % Scalare o stringa tra virgolette
                            result{end+1} = YamlParser.parseValue(firstContent, currentDir);
                        end
                    else
                        idx = idx + 1;
                    end
                end
                remaining = lines(idx:end);

            else
                % Costruiamo una Mappa
                result = struct();
                idx = 1;
                while idx <= length(lines)
                    line = char(lines(idx));
                    currIndent = YamlParser.getIndent(line);

                    if currIndent < indent
                        break;
                    end

                    % Si aspetta "chiave: valore"
                    colonIdx = find(line == ':', 1);
                    if isempty(colonIdx)
                        idx = idx + 1;
                        continue;
                    end

                    key = strtrim(line(1:colonIdx-1));
                    valPart = strtrim(line(colonIdx+1:end));

                    if isempty(valPart)
                        % Blocco annidato
                        % Raccogli righe per il blocco annidato
                        startIdx = idx + 1;
                        nestedIdx = startIdx;
                        while nestedIdx <= length(lines)
                            nLine = char(lines(nestedIdx));
                            nIndent = YamlParser.getIndent(nLine);
                            if nIndent <= currIndent
                                break;
                            end
                            nestedIdx = nestedIdx + 1;
                        end

                        if nestedIdx > startIdx
                            nestedBlock = lines(startIdx:nestedIdx-1);
                            [nestedRes, ~] = YamlParser.parseBlock(nestedBlock, currentDir);
                            result.(key) = nestedRes;
                            idx = nestedIdx;
                        else
                            % Valore vuoto
                            result.(key) = [];
                            idx = idx + 1;
                        end
                    else
                        % Scalare
                        result.(key) = YamlParser.parseValue(valPart, currentDir);
                        idx = idx + 1;
                    end
                end
                remaining = lines(idx:end);
            end
        end

        function val = parseValue(str, currentDir)
            str = strtrim(str);
            if startsWith(str, '"') && endsWith(str, '"')
                val = str(2:end-1);
            elseif startsWith(str, "'") && endsWith(str, "'")
                val = str(2:end-1);
            elseif startsWith(str, '[') && endsWith(str, ']')
                val = str2num(str);
                if isempty(val) && ~strcmp(str, '[]') && ~strcmp(str, '[ ]')
                    % Fallback if conversion fails (e.g. non-numeric list)
                    val = str;
                end
            elseif isnan(str2double(str))
                % È una stringa o booleano
                if strcmpi(str, 'true')
                    val = true;
                elseif strcmpi(str, 'false')
                    val = false;
                elseif endsWith(str, '.yaml', 'IgnoreCase', true)
                    % Gestione inclusione ricorsiva file YAML
                    fullPath = fullfile(currentDir, str);
                    if exist(fullPath, 'file')
                        val = YamlParser.read(fullPath);
                    else
                        val = str; % Se il file non esiste, trattalo come stringa
                    end
                else
                    val = str;
                end
            else
                val = str2double(str);
            end
        end

        function n = getIndent(line)
            n = 0;
            line = char(line);
            for i = 1:length(line)
                if line(i) == ' '
                    n = n + 1;
                else
                    break;
                end
            end
        end
    end
end
