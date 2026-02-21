function varargout = entrypoint()
%ENTRYPOINT Launch the small MVC application.

% Copyright 2021-2025 The MathWorks, Inc.
clear; clc
% Output check.
nargoutchk( 0, 1 )

app = App();

% Return the figure handle if requested.
if nargout == 1
    varargout{1} = app;
end % if

end % entrypoint