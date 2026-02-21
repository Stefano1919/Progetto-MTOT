function html = tableToHtml(T)
% tableToHtml Converts a MATLAB table to an HTML table string.
%   html = tableToHtml(T) returns a string containing the HTML representation
%   of the input table T.

if isempty(T)
    html = "";
    return;
end

% Start table
html = '<table border="1" style="border-collapse: collapse; width: 100%;">';

% Add header row
html = html + "<tr>";
varNames = T.Properties.VariableNames;
for i = 1:length(varNames)
    html = html + "<th style='padding: 8px; text-align: center; background-color: #f2f2f2;'>" + string(varNames{i}) + "</th>";
end
html = html + "</tr>";

% Add data rows
for i = 1:height(T)
    html = html + "<tr>";
    for j = 1:width(T)
        val = T{i, j};
        if isnumeric(val)
            valStr = num2str(val);
        elseif isstring(val) || ischar(val)
            valStr = string(val);
        elseif islogical(val)
            if val
                valStr = "true";
            else
                valStr = "false";
            end
        else
            valStr = string(val);
        end
        html = html + "<td style='padding: 8px; text-align: center; border: 1px solid #ddd;'>" + valStr + "</td>";
    end
    html = html + "</tr>";
end

% End table
html = html + "</table>";
end
