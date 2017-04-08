% *************************************************************************
% * Copyright 2016 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2016-12-30
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
% A simple class for tonemapping image data.
classdef tonemapper < handle
    properties(Access = public)
        scale = 1;
        offset = 0;
        gamma = 1;
        
        method = 'simple';
        
        clamp = true; % clamp to [0, 1] after mapping
    end
    
    properties(Access = protected)
        parent;
        ui; % ui handles
        callback; % update displayed image(s) if the tonemapper's properties are changed
    end
    
    methods(Access = public)
        function obj = tonemapper(varargin)
            assert(numel(varargin) == 0 || numel(varargin) >= 2, ...
                'input must be name value pairs.');
            
            for ii = 1 : 2 : numel(varargin)
                if ~ischar(varargin{ii})
                    error('tonemapper:invalid_input', ...
                        'Inputs should be name-value pairs of parameters.');
                end
                
                switch lower(varargin{ii})
                    case 'scale'
                        obj.scale = double(varargin{ii + 1});
                    case 'offset'
                        obj.offset = double(varargin{ii + 1});
                    case 'gamma'
                        obj.gamma = double(varargin{ii + 1});
                    case 'method'
                        method = varargin{ii + 1};
                        if ~ismember(method, {'simple'})
                            error('tonemapper:illegal_method', ...
                                'method must be ''simple''.');
                        end
                        obj.method = method;
                    case 'callback'
                        obj.callback = varargin{ii + 1};
                    otherwise
                        error('tonemapper:unsupported_argument', ...
                            'unknown parameter name %s', varargin{ii});
                end
            end
        end
        
        function im = tonemap(obj, im, varargin)
            was_img = isa(im, 'img');
            if ~was_img
                im = img(im);
            end
            
            switch obj.method
                case 'simple'
                    im = obj.tonemap_simple(im, varargin{:});
                otherwise
                    error('tonemapper:unsupported_method', ...
                        'unsupported tonemapping method selcte');
            end
            
            if ~was_img
                im = im.cdata;
            end
        end
        
        function handles = create_ui(obj, parent)
            if ~exist('parent', 'var') || isempty(parent)
                parent = figure();
            end
            
            obj.parent = parent;
            
            if ~isa(obj.parent, 'matlab.ui.container.Panel')
                obj.parent = uipanel('Parent', obj.parent);
            end
            obj.parent.Title = 'Tonemapping';
            
            obj.ui_layout();
            obj.ui_initialize();
            handles = obj.ui;
        end
        
        function update(obj)
            obj.callback(obj);
        end
    end
    
    methods(Access = protected)
        function im = tonemap_simple(obj, im, opt)
            % given an image with arbitrarily high dynamic range and
            % potentially multispectral data, this method converts to RGB
            % and reduces the dynamic range by offsetting, scaling and
            % gamma correction; by default, the resulting image is clamped
            % to [0, 1]
            
            if ~isa(im, 'img')
                im = img(im);
            end
            
            % deal with channel numbers ~= 3
            if im.is_monochrome()
                im = repmat(im, 1, 1, 3);
            elseif im.is_spectral()
                im = im.to_rgb();
            elseif im.nc ~= 3
                error('tonemapper:unsupported_channels', ...
                    'unsupported number of channels (%d).', im.nc);
            end
            
            % todo: allow mapping negative values with gamma
            im = obj.scale * tb.clamp(im + obj.offset, 0, inf);
            im = im .^ (1. / obj.gamma);
            
            if obj.clamp
                im = tb.clamp(im, 0, 1);
            end
        end
        
        function ui_layout(obj)
            obj.ui.l0_vbox = uix.VBox('Parent', obj.parent);
            obj.ui.l1_hbox1 = uix.HBox('Parent', obj.ui.l0_vbox);
            obj.ui.l1_hbox2 = uix.HBox('Parent', obj.ui.l0_vbox);
            obj.ui.l1_hbox3 = uix.HBox('Parent', obj.ui.l0_vbox);
            obj.ui.l1_hbox4 = uix.HBox('Parent', obj.ui.l0_vbox);
            obj.ui.l0_vbox.Heights = [20, 20, 20, 28];
        end
        
        function ui_initialize(obj)
            obj.ui.label_scale = uicontrol('Parent', obj.ui.l1_hbox1, ...
                'style', 'text', 'String', 'scale');
            obj.ui.label_offset = uicontrol('Parent', obj.ui.l1_hbox2, ...
                'style', 'text', 'String', 'offset');
            obj.ui.label_gamma = uicontrol('Parent', obj.ui.l1_hbox3, ...
                'style', 'text', 'String', 'gamma');
            obj.ui.label_method = uicontrol('Parent', obj.ui.l1_hbox4, ...
                'style', 'text', 'String', 'method');
            
            obj.ui.edit_scale = uicontrol('Parent', obj.ui.l1_hbox1, ...
                'style', 'edit', 'String', num2str(obj.scale), ...
                'Callback', @obj.ui_callback);
            obj.ui.edit_offset = uicontrol('Parent', obj.ui.l1_hbox2, ...
                'style', 'edit', 'String', num2str(obj.offset), ...
                'Callback', @obj.ui_callback);
            obj.ui.edit_gamma = uicontrol('Parent', obj.ui.l1_hbox3, ...
                'style', 'edit', 'String', num2str(obj.gamma), ...
                'Callback', @obj.ui_callback);
            obj.ui.popup_method = uicontrol('Parent', obj.ui.l1_hbox4, ...
                'style', 'popupmenu', 'String', {'simple'}, ...
                'Value', 1, 'Callback', @obj.ui_callback);
            
            obj.ui.l1_hbox1.Widths = [60, -1];
            obj.ui.l1_hbox2.Widths = [60, -1];
            obj.ui.l1_hbox3.Widths = [60, -1];
            obj.ui.l1_hbox4.Widths = [60, -1];
        end
        
        function ui_callback(obj, src, evnt)
            if src == obj.ui.edit_scale
                try
                    obj.scale = str2double(src.String);
                catch
                    src.String = num2str(obj.scale);
                end
            elseif src == obj.ui.edit_offset
                try
                    obj.offset = str2double(src.String);
                catch
                    src.String = num2str(obj.offset);
                end
            elseif src == obj.ui.edit_gamma
                try
                    obj.gamma = str2double(src.String);
                catch
                    src.String = num2str(obj.gamma);
                end
            elseif src == obj.ui.popup_method
                
            end
            
            if ~isempty(obj.callback)
                obj.callback();
            end
        end
    end
end
