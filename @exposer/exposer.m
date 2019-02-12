% *************************************************************************
% * Copyright 2019 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2019-02-10
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
% Expose an object's properties in a GUI:
%
% e = exposer(obj, {...
%     'field1', 'edit', 1, 10;   % expose obj.field1 in an edit box, bounds [1, 10]
%     'field2', 'slider', 1, 100; % expose obj.field2 in a slider, bounds [1, 100]
%     'field3', 'checkbox', 0, 1}); % expose obj.field3 as checkbox
classdef exposer < handle
    properties
        object;
        meta;
        
        props;
        types;
        dimensions;
        ranges;
        controls;
        callbacks;
        
        nr;
        nc;
        button_size = [-1, 20]
        flex = true; % use GridFlex so UI elements can be resized
        orientation = 'horizontal';
        
        handles;
        container;
        ui;
    end
    
    properties(Constant)
        supported_types = {...
            'logical', ...
            'int8', 'uint8', ...
            'int16', 'uint16', ...
            'int32', 'uint32', ...
            'int64', 'uint64', ...
            'single', 'double', ...
            'char', 'string'};
        supported_dimensions = {'scalar'};
        supported_controls = {'checkbox', 'edit', 'slider', 'spinner'};
    end
    
    methods
        function obj = exposer(object, props, varargin)
            [varargin, obj.container] = arg(varargin, 'container', [], false);
            [varargin, obj.nr] = arg(varargin, 'nr', size(props, 1), false);
            [varargin, obj.nc] = arg(varargin, 'nc', 1, false);
            [varargin, obj.orientation] = arg(varargin, 'orientation', obj.orientation, false);
            [varargin, obj.flex] = arg(varargin, 'flex', obj.flex, false);
            [varargin, obj.button_size] = arg(varargin, 'button_size', obj.button_size, false);
            arg(varargin);
            
            % store object and generate a meta object
            obj.object = object;
            cls = class(obj.object);
            obj.meta = eval(['?', cls]);
            
            % parse mandatory fields from input
            n = size(props, 1);
            assert(size(props, 2) >= 4);
            obj.props = props(:, 1);
            obj.controls = props(:, 2);
            obj.ranges = props(:, 3 : 4);
            
            % parse optional fields
            obj.callbacks = cell(n, 1);
            obj.types = cell(n, 1);
            obj.dimensions = cell(n, 1);
            if size(props, 2) >= 5
                obj.callbacks = props(:, 5);
            end
            if size(props, 2) >= 6
                obj.types = props(:, 6);
            end
            if size(props, 2) >= 7
                obj.dimensions = props(:, 7);
            end
            
            all_props = string({obj.meta.PropertyList.Name})';
            for ii = 1 : n
                p = obj.props{ii};
                ind = find(all_props == p);
                if isempty(ind)
                    error('exposer:invalid_prop', ...
                        'unknown property %s in class %s', p, cls);
                end
                
                % if property types are specified via the @ syntax in the
                % class, we rely on this 
                type = obj.meta.PropertyList(ind).Type.Name;
                val = obj.object.(p);
                if strcmpi(type, 'any')
                    % try to auto detect the property type from its current
                    % value if it hasn't been specified in the class
                    type = class(val);
                end

                if isempty(regexpi(type, ' scalar$| vector$| matrix$'))
                    if ndims(val) == 2 && all(size(val) == 1) %#ok<ISMAT>
                        type = [type, ' scalar']; %#ok<AGROW>
                    elseif ndims(val) == 2 && any(size(val) == 1) && any(size(val) ~= 1) %#ok<ISMAT>
                        type = [type, ' vector']; %#ok<AGROW>
                    elseif ndims(val) == 2 && all(size(val) ~= 1) %#ok<ISMAT>
                        type = [type, ' matrix']; %#ok<AGROW>
                    else
                        type = [type, ' array']; %#ok<AGROW>
                    end
                end

                % now strip off the dimension specifiers and store them
                % separately in the dimensions property
                tokens = regexpi(type, '(.+) (scalar|vector|matrix)$', 'tokens');
                if ~isempty(tokens)
                    type = tokens{1}{1};
                    dim = tokens{1}{2};
                else
                    error('exposer:unsupported_type_spec', ...
                        'unsupported type specifier: %s', type);
                end
                
                if isempty(obj.types{ii})
                    obj.types{ii} = type;
                end
                if isempty(obj.dimensions{ii})
                    obj.dimensions{ii} = dim;
                end
                
                % set default callback
                if isempty(obj.callbacks{ii})
                    obj.callbacks{ii} = @(value, prop) setfield(obj.object, prop, value);
                end
            end
            
            % check if all types are supported
            unsupported_types = setdiff(obj.types, obj.supported_types);
            if ~isempty(unsupported_types)
                error('exposer:unsupported_type', ...
                    'the following types are not supported: %s', ...
                    tb.to_str(unsupported_types));
            end
            
            % check if all dimensions are supported
            unsupported_dims = setdiff(obj.dimensions, obj.supported_dimensions);
            if ~isempty(unsupported_dims)
                error('exposer:unsupported_dim', ...
                    'the following dimensions are not supported: %s', ...
                    tb.to_str(unsupported_dims));
            end
            
            % check if all dimensions are supported
            unsupported_controls = setdiff(obj.controls, obj.supported_controls);
            if ~isempty(unsupported_controls)
                error('exposer:unsupported_control', ...
                    'the following controls are not supported: %s', ...
                    tb.to_str(unsupported_controls));
            end
            
            if isempty(obj.nr)
                obj.nr = floor(sqrt(numel(obj.props)));
            end
            if isempty(obj.nc)
                obj.nc = ceil(numel(obj.props) / obj.nr);
            end
            
            obj.ui_init();
        end
        
        function ui_init(obj)
            % create UI elements
            if isempty(obj.container)
                % create new figure if no container is specified
                obj.container = figure('MenuBar', 'none', 'ToolBar', 'none');
            end
            % create layout: first level is grid layout that stores the columns
            if obj.flex
                obj.ui.l0_grid = uiextras.GridFlex('Parent', obj.container);
            else
                obj.ui.l0_grid = uiextras.Grid('Parent', obj.container);
            end
            % second level are VBoxes that store the rows
            obj.ui.l1_bbs = cell(1, obj.nc);
            for ci = 1 : obj.nc
                if obj.flex
                    obj.ui.l1_bbs{ci} = uiextras.VBoxFlex('Parent', obj.ui.l0_grid);
                else
                    obj.ui.l1_bbs{ci} = uiextras.VBox('Parent', obj.ui.l0_grid);
                end
            end
            
            % create the individual UI elements
            obj.handles = cell(numel(obj.props), 1);
            for ii = 1 : numel(obj.props)
                [~, ci] = ind2sub([obj.nr, obj.nc], ii);
                value = obj.object.(obj.props{ii});
                if strcmpi(obj.controls{ii}, 'checkbox')
                    control = @uicontrol;
                    params = {'Style', 'checkbox', ...
                        'Value', value, ...
                        'Callback', @(src, evnt) obj.callback(src, evnt, ii, src.Value)};
                elseif strcmpi(obj.controls{ii}, 'edit')
                    control = @uicontrol;
                    params = {'Style', 'edit', ...
                        'String', char(tb.to_str(value)), ...
                        'Callback', @(src, evnt) obj.callback(src, evnt, ii, src.String)};
                elseif strcmpi(obj.controls{ii}, 'slider')
                    control = @uicontrol;
                    % no callback here to prevent repeated triggering after
                    % the continuous callback (see below)
                    params = {'Style', 'slider', ...
                        'Min', obj.ranges{id, 1}, ...
                        'Max', obj.ranges{id, 2}, ...
                        'Value', value};
                elseif strcmpi(obj.controls{ii}, 'spinner')
                    control = @uispinner;
                    params = {'value', value, ...
                        'callback', @(src, value) obj.callback(src, [], ii, value)};
                else
                    error('exposer:unsupported_control', ...
                        'unsupported uicontrol: %s', obj.controls{ii});
                end
                
                % create labeled control
                obj.handles{ii} = uipair(obj.ui.l1_bbs{ci}, obj.orientation, ...
                    @uicontrol, {'Style', 'text', 'String', obj.props{ii}, ...
                    'HorizontalAlignment', ternary(strcmpi(obj.orientation, 'horizontal'), ...
                    'right', 'left')}, ...
                    control, params);
                
                % continuous slider callback
                if strcmpi(obj.controls{ii}, 'slider')
                    addlistener(obj.handles{ii}.h2, 'Value', 'PostSet', ...
                        @(src, evnt) obj.callback(src, evnt, ii, evnt.AffectedObject.Value));
                end
            end
            
            % layout
            set(obj.ui.l0_grid, 'Heights', -1, ...
                'Widths', repmat(-1, obj.nc, 1));
            for ci = 1 : obj.nc
                num_children = numel(obj.ui.l1_bbs{ci}.Children);
                obj.ui.l1_bbs{ci}.Heights = repmat(obj.button_size(2), num_children, 1);
            end
        end
        
        function callback(obj, src, evnt, ii, value) %#ok<INUSL>
            % callback wrapper that does type conversion & bound checks and
            % updates the UI after setting the values
            if ismember(obj.types{ii}, {...
                'logical', ...
                'int8', 'uint8', ...
                'int16', 'uint16', ...
                'int32', 'uint32', ...
                'int64', 'uint64', ...
                'single', 'double'})
                % numeric types
                if ischar(value)
                    value = str2double(value);
                end
                
                % bounds checking if requested
                if ~isempty(obj.ranges{ii, 1}) && ~isempty(obj.ranges{ii, 2})
                    value = min(obj.ranges{ii, 2}, max(obj.ranges{ii, 1}, value));
                end
                
                % ensure type matches
                value = cast(value, obj.types{ii});
            elseif ismember(obj.types{ii}, {'char', 'string'})
                % char / string
            else
                error('exposer:unsupported_type', 'unsupported type %s', obj.types{ii});
            end
            if nargin(obj.callbacks{ii}) > 1
                obj.callbacks{ii}(value, obj.props{ii});
            else
                obj.callbacks{ii}(value);
            end
            
            % read back value from object to update the UI in case the
            % value differs after setting
            value_new = obj.object.(obj.props{ii});
            
            if any(strcmpi(obj.controls{ii}, {'checkbox', 'slider'}))
                obj.handles{ii}.h2.Value = value_new;
            elseif strcmpi(obj.controls{ii}, 'edit')
                obj.handles{ii}.h2.String = char(tb.to_str(value));
            elseif strcmpi(obj.controls{ii}, 'spinner')
                obj.handles{ii}.set_value(value);
            else
                error('exposer:unsupported_uicontrol', ...
                    'unsupported uicontrol: %s', obj.controls{ii});
            end
        end
    end
end
