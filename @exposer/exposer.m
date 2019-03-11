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
% e = exposer(obj);
%
% e = exposer(obj, 'props', {...
%     'field1', 'edit', {1, 10};   % expose obj.field1 in an edit box, bounds [1, 10]
%     'field2', 'slider', {1, 100}; % expose obj.field2 in a slider, bounds [1, 100]
%     'field3', 'checkbox', {0, 1}}); % expose obj.field3 as checkbox
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
        
        scrollable = true;
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
            'logical', 'onoff', ...
            'int8', 'uint8', ...
            'int16', 'uint16', ...
            'int32', 'uint32', ...
            'int64', 'uint64', ...
            'single', 'double', ...
            'char', 'string', ...
            'numericorstring'};
        supported_dimensions = {'scalar', 'vector', 'matrix'};
        supported_controls = {'checkbox', 'edit', 'popupmenu', 'slider', 'spinner'};
        type_map = {...
            'matlab.graphics.datatype.ActivePosition', 'char', 'scalar', {'position', 'outerposition'}, 'popupmenu';
            'matlab.graphics.datatype.AlphaDataMapping', 'char', 'scalar', {'none', 'scaled', 'direct'}, 'popupmenu';
            'matlab.graphics.datatype.Alphamap', 'numericorstring', 'vector', {0, 1}, 'edit';
            'matlab.graphics.datatype.AnyData', 'double', 'matrix', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.AutoManual', 'char', 'scalar', {'auto', 'manual'}, 'popupmenu';
            'matlab.graphics.datatype.AxesNextPlot', 'char', 'scalar', {'add', 'replace', 'replacechildren', 'replaceall'}, 'popupmenu';
            'matlab.graphics.datatype.AxesView', 'double', 'vector', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.AxisDirection', 'char', 'scalar', {'normal', 'reverse'}, 'popupmenu';
            'matlab.graphics.datatype.AxisScale', 'char', 'scalar', {'linear', 'log'}, 'popupmenu';
            'matlab.graphics.datatype.AxisTopBottom', 'char', 'scalar', {'bottom', 'top'}, 'popupmenu';
            'matlab.graphics.datatype.AxisXLocation', 'char', 'scalar', {'bottom', 'top', 'origin'}, 'popupmenu';
            'matlab.graphics.datatype.AxisYLocation', 'char', 'scalar', {'left', 'right', 'origin'}, 'popupmenu';
            'matlab.graphics.datatype.AxesBox', 'char', 'scalar', {'full', 'back'}, 'popupmenu';
            'matlab.graphics.datatype.BackFaceLighting', 'char', 'scalar', {'reverselit', 'unlit', 'lit'}, 'popupmenu';
            'matlab.graphics.datatype.BusyAction', 'char', 'scalar', {'cancel', 'queue'}, 'popupmenu';
            'matlab.graphics.datatype.CDataMapping', 'char', 'scalar', {'scaled', 'direct'}, 'popupmenu';
            'matlab.graphics.datatype.ClippingStyle', 'char', 'scalar', {'rectangle', '3dbox'}, 'popupmenu';
            'matlab.graphics.datatype.Colormap', 'numericorstring', 'matrix', {0, 1}, 'edit';
            'matlab.graphics.datatype.Finite', 'double', 'scalar', {@isfinite}, 'edit';
            'matlab.graphics.datatype.MeshAlpha', 'double', 'scalar', {0, 1}, 'slider';
            'matlab.graphics.datatype.FontAngle', 'char', 'scalar', {'normal', 'italic'}, 'popupmenu';
            'matlab.graphics.datatype.FontName', 'char', 'scalar', {}, 'edit';
            'matlab.graphics.datatype.FontWeight', 'char', 'scalar', {'normal', 'bold'}, 'popupmenu';
            'matlab.graphics.datatype.FontUnits', 'char', 'scalar', {'inches', 'centimeters', 'normalized', 'points', 'pixels'}, 'popupmenu';
            'matlab.graphics.datatype.HandleVisibility', 'char', 'scalar', {'on', 'callback', 'off'}, 'popupmenu';
            'matlab.graphics.datatype.IndexVector', 'double', 'vector', {1, inf}, 'edit';
            'matlab.graphics.datatype.Lighting', 'char', 'scalar', {'none', 'flat', 'gouraud'}, 'popupmenu';
            'matlab.graphics.datatype.LightingStrength', 'double', 'scalar', {0, 1}, 'slider';
            'matlab.graphics.datatype.LimitsAny', 'double', 'vector', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.LimitsWithInfs', 'double', 'vector', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.LineJoin', 'char', 'scalar', {'chamfer', 'miter', 'round'}, 'popupmenu';
            'matlab.graphics.datatype.LineStyle', 'char', 'scalar', {}, 'edit';
            'matlab.graphics.datatype.MarkerColor', 'numericorstring', 'vector', {0, 1}, 'edit';
            'matlab.graphics.datatype.MarkerStyle', 'char', 'scalar', {}, 'edit';
            'matlab.graphics.datatype.NextPlot', 'char', 'scalar', {'new', 'add', 'replace', 'replacechildren'}, 'popupmenu';
            'matlab.graphics.datatype.NumericOrString', 'numericorstring', 'scalar', {{}}, 'edit';
            'matlab.graphics.datatype.PatchColor', 'numericorstring', 'matrix', {0, 1}, 'edit';
            'matlab.graphics.datatype.PickableParts', 'char', 'scalar', {'visible', 'none', 'all'}, 'popupmenu';
            'matlab.graphics.datatype.Position', 'double', 'vector', {0, inf}, 'edit';
            'matlab.graphics.datatype.Positive', 'double', 'scalar', {0, inf}, 'edit';
            'matlab.graphics.datatype.PositiveInteger', 'uint64', 'scalar', {0, inf}, 'edit';
            'matlab.graphics.datatype.Projection', 'char', 'scalar', {'orthographic', 'perspective'}, 'edit';
            'matlab.graphics.datatype.RGBAColor', 'double', 'vector', {0, 1}, 'edit';
            'matlab.graphics.datatype.RGBAutoNoneColor', 'numericorstring', 'scalar', {}, 'edit';
            'matlab.graphics.datatype.RGBFlatNoneColor', 'numericorstring', 'scalar', {}, 'edit';
            'matlab.graphics.datatype.RenderEngineType', 'char', 'scalar', {'painters', 'opengl'}, 'popupmenu';
            'matlab.graphics.datatype.SortMethod', 'char', 'scalar', {'depth', 'childorder'}, 'popupmenu';
            'matlab.graphics.datatype.TextInterpreter', 'char', 'scalar', {'none', 'tex', 'latex'}, 'popupmenu';
            'matlab.graphics.datatype.TickAny', 'double', 'vector', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.TickDir', 'char', 'scalar', {'in', 'out', 'both'}, 'popupmenu';
            'matlab.graphics.datatype.Units', 'char', 'scalar', {'pixels', 'normalized'}, 'popupmenu';
            'matlab.graphics.datatype.View', 'double', 'vector', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.ZeroToOne', 'double', 'scalar', {0, 1}, 'slider';
            ...
            'matlab.graphics.datatype.NumericOrLogicalMatrix', 'double', 'matrix', {0, inf}, 'edit';
            'matlab.graphics.datatype.CompositeColorData', 'double', 'array', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.ImageXYData', 'double', 'vector', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.NumericMatrix', 'double', 'matrix', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.Numeric2D3DMatrix', 'double', 'matrix', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.Point2d', 'double', 'vector', {0, inf}, 'edit';
            'matlab.graphics.datatype.Point3', 'double', 'vector', {-inf, inf}, 'edit';
            'matlab.graphics.datatype.PositiveOrNanVectorData', 'double', 'vector', {0, inf}, 'edit';
            'matlab.graphics.datatype.PositivePoint3', 'double', 'vector', {0, inf}, 'edit';
            'matlab.graphics.datatype.TickLength', 'double', 'vector', {0, inf}, 'edit';
            ...
            'matlab.ui.datatype.PaperOrientation', 'char', 'scalar', {'portrait', 'landscape', 'rotated'}, 'popupmenu';
            'matlab.ui.datatype.PaperUnits', 'char', 'scalar', {'inches', 'centimeters', 'normalzied', 'points'}, 'popupmenu';
            'matlab.ui.datatype.PaperType', 'char', 'scalar', {'usletter', 'uslegal', 'A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'B0', 'B1', 'B2', 'B3', 'B4', 'B5', 'A', 'B', 'C', 'D', 'E', 'arch-A', 'arch-B', 'arch-C', 'arch-D', 'arch-E', 'tabloid', '<custom>'}, 'popupmenu';
            'matlab.ui.datatype.FigureMenuBar', 'char', 'scalar', {'none', 'figure'}, 'popupmenu';
            'matlab.ui.datatype.PointerShape', 'char', 'scalar', {'arrow', 'ibeam', 'crosshair', 'watch', 'topl', 'topr', 'botl', 'botr', 'circle', 'cross', 'fleur', 'custom', 'left', 'top', 'right', 'bottom', 'hand'}, 'popupmenu';
            'matlab.ui.datatype.PointerShapeCData', 'double', 'matrix', {0, 1}, 'edit';
            'matlab.ui.datatype.PointerShapeHotSpot', 'double', 'vector', {1, 32}, 'edit';
            'matlab.ui.datatype.FigureToolBar', 'char', 'scalar', {'none', 'auto', 'figure'}, 'popupmenu';
            'matlab.ui.datatype.WindowStyle', 'char', 'scalar', {'normal', 'modal', 'docked'}, 'popupmenu';
            ...
            'asciiString', 'char', 'scalar', {}, 'edit';
            'unicodeString', 'char', 'scalar', {}, 'edit'};
    end
    
    methods
        function obj = exposer(object, varargin)
            [varargin, props] = arg(varargin, 'props', [], false);
            [varargin, show_hidden] = arg(varargin, 'show_hidden', false, false);
            [varargin, do_sort] = arg(varargin, 'sort', true, false);
            [varargin, obj.container] = arg(varargin, 'container', [], false);
            [varargin, obj.orientation] = arg(varargin, 'orientation', obj.orientation, false);
            [varargin, obj.scrollable] = arg(varargin, 'scrollable', obj.scrollable, false);
            [varargin, obj.nr] = arg(varargin, 'nr', [], false);
            [varargin, obj.nc] = arg(varargin, 'nc', [], false);
            [varargin, obj.flex] = arg(varargin, 'flex', obj.flex, false);
            [varargin, obj.button_size] = arg(varargin, 'button_size', obj.button_size, false);
            arg(varargin);
            
            % store object and generate a meta object
            obj.object = object;
            cls = class(obj.object);
            obj.meta = eval(['?', cls]);
            
            if isempty(props)
                % no props array specified -> automatically extract all
                % possible properties from the provided object
                obj.props = cell(0, 1);
                obj.types = cell(0, 1);
                obj.dimensions = cell(0, 1);
                obj.callbacks = cell(0, 1);
                obj.ranges = cell(0, 1);
                
                % try to automatically get all useable properties of object
                for ii = 1 : numel(obj.meta.PropertyList)
                    prop = obj.meta.PropertyList(ii).Name;
                    type = obj.meta.PropertyList(ii).Type.Name;
                    
                    if any(strcmp(obj.meta.PropertyList(ii).GetAccess, {'protected', 'private'})) ...
                            || iscell(obj.meta.PropertyList(ii).SetAccess) ...
                            || any(strcmp(obj.meta.PropertyList(ii).SetAccess, {'protected', 'private'})) ...
                            || obj.meta.PropertyList(ii).Constant
                        % skip non-public properties
                        continue;
                    end
                    if ~show_hidden && obj.meta.PropertyList(ii).Hidden
                        % skip hidden properties
                        continue;
                    end
                    if regexp(prop, '_I$')
                        % skip duplicate properties in Matlab graphics objects
                        continue;
                    end
                    
                    % try to parse potential type specifiers
                    tokens = regexpi(type, '(.+) (scalar|vector|matrix)$', 'tokens');
                    if ~isempty(tokens)
                        % type specifier with dimensions available
                        type = tokens{1}{1};
                        dimension = tokens{1}{2};
                    else
                        % no type specifiers -> extract the property value
                        val = obj.object.(prop);
                        % use current value to determine dimensionality
                        dimension = exposer.get_dimension(val);
                    end
                    
                    if strcmpi(type, 'logical')
                        range = {0, 1};
                        control = 'checkbox';
                    else
                        range = {-inf, inf};
                        control = 'edit';
                    end
                    
                    if ~ismember(type, obj.supported_types) ...
                            || ~ismember(dimension, obj.supported_dimensions)
                        [type, dimension, range, control] = obj.translateMatlabType(type);
                        
                        if ~ismember(type, obj.supported_types) ...
                                || ~ismember(dimension, obj.supported_dimensions)
                            [prop, ': ', type]
                            continue;
                        end
                    end
                    
                    obj.props{end + 1, 1} = prop;
                    obj.types{end + 1, 1} = type;
                    obj.dimensions{end + 1, 1} = dimension;
                    obj.ranges{end + 1} = range;
                    obj.controls{end + 1} = control;
                    
                    % default callback directly sets the property
                    obj.callbacks{end + 1, 1} = @(value, prop) setfield(obj.object, prop, value);
                end
            else
                % parse mandatory fields from input
                n = size(props, 1);
                assert(size(props, 2) >= 3);
                obj.props = props(:, 1);
                obj.controls = props(:, 2);
                obj.ranges = props(:, 3);

                % parse optional fields
                obj.callbacks = cell(n, 1);
                obj.types = cell(n, 1);
                obj.dimensions = cell(n, 1);
                if size(props, 2) >= 4
                    % callbacks specified
                    obj.callbacks = props(:, 4);
                end
                if size(props, 2) >= 5
                    % types specified
                    obj.types = props(:, 5);
                end
                if size(props, 2) >= 6
                    % dimensions specified
                    obj.dimensions = props(:, 6);
                end

                all_props = string({obj.meta.PropertyList.Name})';
                for ii = 1 : n
                    prop = obj.props{ii};
                    ind = find(all_props == prop);
                    if isempty(ind)
                        error('exposer:invalid_prop', ...
                            'unknown property %s in class %s', prop, cls);
                    end

                    % if property types are specified via the @ syntax in the
                    % class, we rely on this 
                    type = obj.meta.PropertyList(ind).Type.Name;

                    % try to parse potential type specifiers
                    tokens = regexpi(type, '(.+) (scalar|vector|matrix)$', 'tokens');
                    if ~isempty(tokens)
                        % type specifier with dimensions available
                        type = tokens{1}{1};
                        dim = tokens{1}{2};
                    else
                        % no type specifiers -> extract the property value
                        val = obj.object.(prop);
                        
                        % try to auto detect the property type from its
                        % current value
                        type = class(val);
                        % also use current value to determine dimensionality
                        dim = exposer.get_dimension(val);
                    end
                    
                    if regexp(type, 'on_off')
                        % "boolean" values with 'on' / 'off' need special
                        % treatment (used throughout Matlab's handle
                        % classes)
                        type = 'onoff';
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
            end
            
            if do_sort
                % sort properties alphabetically
                [obj.props, perm] = sort(obj.props);
                obj.types = obj.types(perm);
                obj.dimensions = obj.dimensions(perm);
                obj.ranges = obj.ranges(perm);
                obj.controls = obj.controls(perm);
                obj.callbacks = obj.callbacks(perm);
            end
            
            % automatically find good arrangement of the controls inside
            % the container
            if isempty(obj.nr)
                if ~isempty(obj.nc)
                    obj.nr = ceil(numel(obj.props) / obj.nc);
                else
                    obj.nr = floor(sqrt(numel(obj.props)));
                end
            end
            if isempty(obj.nc)
                obj.nc = ceil(numel(obj.props) / obj.nr);
            end
            
            obj.ui_init();
        end
        
        function [type, dimension, range, control] = translateMatlabType(obj, type)
            ind = find(strcmpi(obj.type_map(:, 1), type));
            if ~isempty(ind)
                type = obj.type_map{ind, 2};
                dimension = obj.type_map{ind, 3};
                range = obj.type_map{ind, 4};
                control = obj.type_map{ind, 5};
            elseif regexp(type, 'on_off')
                % "boolean" values with 'on' / 'off' need special
                % treatment (used throughout Matlab's handle
                % classes)
                type = 'onoff';
                dimension = 'scalar';
                range = {0, 1};
                control = 'checkbox';
            else
                dimension = [];
                range = [];
                control = [];
                warning('exposer:unsupported_type', ...
                    'request for unsupported type translation: %s', type);
            end
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
            obj.ui.l1_scroll = cell(1, obj.nc);
            for ci = 1 : obj.nc
                if obj.scrollable
                    obj.ui.l1_scroll{ci} = uix.ScrollingPanel('Parent', obj.ui.l0_grid);
                    if obj.flex
                        obj.ui.l1_bbs{ci} = uiextras.VBoxFlex('Parent', obj.ui.l1_scroll{ci});
                    else
                        obj.ui.l1_bbs{ci} = uiextras.VBox('Parent', obj.ui.l1_scroll{ci});
                    end
                else
                    if obj.flex
                        obj.ui.l1_bbs{ci} = uiextras.VBoxFlex('Parent', obj.ui.l0_grid);
                    else
                        obj.ui.l1_bbs{ci} = uiextras.VBox('Parent', obj.ui.l0_grid);
                    end
                end
            end
            
            % create the individual UI elements
            obj.handles = cell(numel(obj.props), 1);
            for ii = 1 : numel(obj.props)
                [~, ci] = ind2sub([obj.nr, obj.nc], ii);
                value = obj.object.(obj.props{ii});
                if strcmpi(obj.types{ii}, 'onoff')
                    value = onoff2bool(value);
                end
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
                elseif strcmpi(obj.controls{ii}, 'popupmenu')
                    control = @uicontrol;
                    vals = obj.ranges{ii};
                    index = find(strcmp(vals, value));
                    params = {'Style', 'popupmenu', ...
                        'String', vals, ...
                        'Value', index, ...
                        'Callback', @(src, evnt) obj.callback(src, evnt, ii, src.String{src.Value})};
                elseif strcmpi(obj.controls{ii}, 'slider')
                    control = @uicontrol;
                    % no callback here to prevent repeated triggering after
                    % the continuous callback (see below)
                    params = {'Style', 'slider', ...
                        'Min', obj.ranges{ii}{1}, ...
                        'Max', obj.ranges{ii}{2}, ...
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
                if ~isempty(obj.ui.l1_scroll{ci})
                    if obj.button_size(2) > 0
                        obj.ui.l1_scroll{ci}.Heights = num_children...
                            * (obj.button_size(2) + obj.ui.l1_bbs{ci}.Spacing)...
                            + 2 * obj.ui.l1_bbs{ci}.Padding;
                    else
                        error('exposer:invalid_button_size', ...
                            ['please specify an absolute button height if you want', ...
                            'a scrollable container']);
                    end
                end
            end
        end
        
        function handle = get_control(obj, prop, varargin)
            % return a control handle for a specific property
            [varargin, split_uipair] = arg(varargin, 'split_uipair', true, false);
            arg(varargin);
            
            handle = obj.handles{find(string(obj.props(:, 1)) == prop)}; %#ok<FNDSB>
            
            if split_uipair && ~isempty(handle) && isa(handle, 'uipair')
                handle = handle.h2;
            end
        end
        
        function callback(obj, src, evnt, ii, value) %#ok<INUSL>
            % callback wrapper that does type conversion & bound checks and
            % updates the UI after setting the values
            if strcmp(obj.dimensions{ii}, 'scalar')
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
                    if ~isempty(obj.ranges{ii}{1}) && ~isempty(obj.ranges{ii}{2})
                        value = min(obj.ranges{ii}{2}, max(obj.ranges{ii}{1}, value));
                    end

                    % ensure type matches
                    value = cast(value, obj.types{ii});
                elseif strcmp(obj.types{ii}, 'onoff')
                    % 'on' / 'off' valued property
                    value = bool2onoff(value);
                elseif ismember(obj.types{ii}, {'char', 'string'})
                    % char / string
                elseif strcmp(obj.types{ii}, 'numericorstring')
                    % numbers / chars / strings
                    tmp = tb.str2mat2(value);
                    if ~isempty(tmp) && isnumeric(tmp) && ~any(isnan(tmp))
                        value = tmp;
                    end
                else
                    error('exposer:unsupported_type', 'unsupported type %s', obj.types{ii});
                end
            else
                if ismember(obj.types{ii}, {...
                    'logical', ...
                    'int8', 'uint8', ...
                    'int16', 'uint16', ...
                    'int32', 'uint32', ...
                    'int64', 'uint64', ...
                    'single', 'double'})
                    value = tb.str2mat2(value);
                else
                    error('not implemented yet');
                end
            end
            
            if nargin(obj.callbacks{ii}) > 2
                obj.callbacks{ii}(value, obj.props{ii}, obj.handles{ii})
            elseif nargin(obj.callbacks{ii}) > 1
                obj.callbacks{ii}(value, obj.props{ii});
            else
                obj.callbacks{ii}(value);
            end
            
            % read back value from object to update the UI in case the
            % value differs after setting
            value_new = obj.object.(obj.props{ii});
            if strcmp(obj.types{ii}, 'onoff')
                value_new = onoff2bool(value_new);
            end
            if any(strcmpi(obj.controls{ii}, {'checkbox', 'slider'}))
                obj.handles{ii}.h2.Value = value_new;
            elseif strcmpi(obj.controls{ii}, 'edit')
                obj.handles{ii}.h2.String = char(tb.to_str(value));
            elseif strcmpi(obj.controls{ii}, 'popupmenu')
                ind = find(strcmp(obj.handles{ii}.h2.String, value));
                obj.handles{ii}.h2.Value = ind;
            elseif strcmpi(obj.controls{ii}, 'spinner')
                obj.handles{ii}.set_value(value);
            else
                error('exposer:unsupported_uicontrol', ...
                    'unsupported uicontrol: %s', obj.controls{ii});
            end
        end
    end
    
    methods(Static)
        function dim = get_dimension(val)
            if ischar(val)
                dim = 'scalar';
            elseif ndims(val) == 2 && all(size(val) == 1) %#ok<ISMAT>
                dim = 'scalar';
            elseif ndims(val) == 2 && any(size(val) == 1) && any(size(val) ~= 1) %#ok<ISMAT>
                dim = 'vector';
            elseif ndims(val) == 2 && all(size(val) ~= 1) %#ok<ISMAT>
                dim = 'matrix';
            else
                dim = 'array';
            end
        end
    end
end
