% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-04-01
% *
% * This file is part of smml.
% *
% * smml is free software: you can redistribute it and/or modify it under
% * the terms of the GNU Lesser General Public License as published by the
% * Free Software Foundation, either version 3 of the License, or (at your
% * option) any later version.
% *
% * smml is distributed in the hope that it will be useful, but WITHOUT
% * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
% * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
% * License for more details.
% *
% * You should have received a copy of the GNU Lesser General Public
% * License along with smml.  If not, see <http://www.gnu.org/licenses/>.
% *
% *************************************************************************
% 
% Simple wrapper around uicontrol that groups two ui elements. Currently it
% either allows to put a uicontrol inside a uipanel, or two uicontrols into
% a grid container with horizontal or vertical alignment.
% This allows to easily label uicontrols without having to deal with
% layouts.
% The underlying ui objects are stored as the members h1 and h2 and can be
% accessed publicly.
classdef uipair < handle
    properties
        parent;
        grid;
        h1;
        h2;
    end
    
    methods
        function obj = uipair(parent, orientation, fn1, params1, fn2, params2)
            % construct a uipair by specifying the parent handle, the
            % functions to call (either uipanel or uicontrol) and the
            % parameters to pass to these functions as a cell array of name
            % value pairs
            if ~exist('orientation', 'var') || isempty(orientation)
                orientation = 'vertical';
            end
            
            assert(ismember(lower(orientation), {'horizontal', 'vertical'}), ...
                'orientation must be ''horizontal'' or ''vertical''.');

            assert(isa(fn1, 'function_handle') && ...
                ismember(func2str(fn1), {'uipanel', 'uicontrol', 'button'}), ...
                'fn1 must be one of @uipanel or @uicontrol.');
            assert(isa(fn2, 'function_handle') && ...
                ismember(func2str(fn2), {'uipanel', 'uicontrol', 'button'}), ...
                'fn2 must be one of @uipanel or @uicontrol.');
            
            obj.parent = parent;
            
            if strcmpi(func2str(fn1), 'uipanel') || strcmpi(func2str(fn1), 'uicontrol')
                params1 = uipair.standardize_params(params1);
            end
            
            if strcmpi(func2str(fn2), 'uipanel') || strcmpi(func2str(fn2), 'uicontrol')
                params2 = uipair.standardize_params(params2);
            end
            
            if strcmpi(func2str(fn1), 'uipanel')
                % uipanel with one uicontrol inside it
                obj.h1 = uipair.create_ui(fn1, obj.parent, params1);
                obj.h2 = uipair.create_ui(fn2, obj.h1, params2);
            else
                % grid with two uicontrols
                obj.grid = uix.Grid('Parent', parent);
                obj.h1 = uipair.create_ui(fn1, obj.grid, params1);
                obj.h2 = uipair.create_ui(fn2, obj.grid, params2);
                
                if strcmpi(orientation, 'horizontal')
                    obj.grid.Widths = [-1, -2];
                else
                    obj.grid.Heights = [-2, -1];
                end
            end
        end
    end
    
    methods(Static)
        function h = create_ui(fn, parent, params)
            % create ui element
            switch lower(func2str(fn))
                case 'uipanel'
                    h = uipanel(parent, params{:});
                case 'uicontrol'
                    h = uicontrol(parent, params{:});
                otherwise
%                     try
                        h = fn(parent, params{:});
%                         h = h.get_handle();
%                     catch err
%                         error('uipair:invalid_fcn_handle', ...
%                             ['unsupported function handle %s\n', ...
%                             'error: %s'], func2str(fn), err.message);
%                     end
            end
        end
        
        function params = standardize_params(params)
            % extract important parameters, e.g. the uicontrol style, units
            % and position which should be passed to uicontrol in a
            % specific order.
            
            % extract style argument
            style_ind = find(cellfun(@(x) strcmpi(x, 'Style'), params(1 : 2 : end))) * 2 - 1;
            if ~isempty(style_ind)
                style = params{style_ind + 1};
            else
                style = [];
            end
            
            % extract units argument
            units_ind = find(cellfun(@(x) strcmpi(x, 'Units'), params(1 : 2 : end))) * 2 - 1;
            if ~isempty(units_ind)
                units = params{units_ind + 1};
            else
                units = 'normalized';
            end
            
            % extract position argument
            pos_ind = find(cellfun(@(x) strcmpi(x, 'Position'), params(1 : 2 : end))) * 2 + 1;
            if ~isempty(pos_ind)
                position = params{pos_ind + 1};
            else
                position = [0, 0, 1, 1];
            end
            
            % remove the above arguments, if they existed
            params([style_ind, style_ind + 1, ...
                units_ind, units_ind + 1, ...
                pos_ind, pos_ind + 1]) = [];
            
            if isempty(style)
                params = [{'Units', units, 'Position', position}, ...
                    params(:)'];
            else
                params = [{'Style', style, 'Units', units, 'Position', position}, ...
                    params(:)'];
            end
        end
    end
end
