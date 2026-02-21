classdef ( Abstract ) Component < matlab.ui.componentcontainer.ComponentContainer
    %COMPONENT Superclass for implementing views and controllers.

    % Copyright 2021-2025 The MathWorks, Inc.

    properties ( SetAccess = immutable, GetAccess = protected )
        % % Application data model.
        % Modello(:, 1) Model
    end % properties ( SetAccess = immutable, GetAccess = protected )

    methods

        function obj = Component()
            %COMPONENT Component constructor.)

            % Do not create a default figure parent for the component, and
            % ensure that the component spans its parent. By default,
            % ComponentContainer objects are auto-parenting - that is, a
            % figure is created automatically if no parent argument is
            % specified.
            obj@matlab.ui.componentcontainer.ComponentContainer( ...
                "Parent", [], ...
                "Units", "normalized", ...
                "Position", [0, 0, 1, 1] )

        end % constructor

    end % methods

end % classdef