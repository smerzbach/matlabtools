% *************************************************************************
% * Copyright 2019 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2019-08-31
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
% Simple wrapper around uicontrol that groups multiple ui elements in
% horizontal or vertical alignment. This allows to easily label uicontrols
% without having to deal with layouts.
% The underlying ui objects are stored in the handles property which can be
% accessed publicly.
classdef uigroup < handle
    properties
        parent;
        grid;
        handles;
    end
    
    methods
        function obj = uigroup(parent, orientation, varargin)
            % construct a uigroup by specifying the parent handle, the
            % functions to create the ui elements and the parameters to
            % pass to these functions as a cell array of name value pairs
            if ~exist('orientation', 'var') || isempty(orientation)
                orientation = 'vertical';
            end
            
            obj.parent = handle(parent);
            
            assert(ismember(lower(orientation), {'horizontal', 'vertical'}), ...
                'orientation must be ''horizontal'' or ''vertical''.');
            
            fnInds = find(cellfun(@(arg) isa(arg, 'function_handle') || ...
                (isa(arg, 'char') && ismember(arg, {'uicontrol', 'uispinner'})), varargin));
            paramInds = fnInds + 1;
            assert(all(cellfun(@iscell, varargin(paramInds))), ...
                'function handles / names must be followed by cell arrays of parameters');
            
            fns = varargin(fnInds);
            params = varargin(paramInds);
            n = numel(fns);
            
            noHandle = ~cellfun(@(fn) isa(fn, 'function_handle'), fns);
            fns(noHandle) = cfun(@(fn) str2func(fn), fns(noHandle));
            
            for fi = 1 : numel(fns)
                if strcmpi(func2str(fns{fi}), 'uicontrol')
                    params{fi} = uigroup.standardize_params(params{fi});
                end
            end
            
            obj.handles = cell(n, 1);

            % grid with two uicontrols
            obj.grid = uiextras.Grid('Parent', obj.parent);
            for ii = 1 : n
                obj.handles{ii} = uigroup.create_ui(fns{ii}, obj.grid, params{ii});
            end

            if strcmpi(orientation, 'horizontal')
                obj.grid.ColumnSizes = [-1, -2 / (n - 1) * ones(1, n - 1)];
            else
                obj.grid.RowSizes = [-2 / (n - 1) * ones(1, n - 1), -1];
            end
        end
        
        function handle = h1(obj)
            handle = obj.handles{1};
        end
        
        function handle = h2(obj)
            handle = obj.handles{2};
        end
    end
    
    methods(Static)
        function h = create_ui(fn, parent, params)
            % create ui element
            if strcmpi(func2str(fn), 'uicontrol')
                h = handle(uicontrol('Parent', parent, params{:}));
            else
                h = handle(fn(parent, params{:}));
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
