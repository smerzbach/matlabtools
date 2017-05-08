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
        raw_mode = false; % for single channel selection of spectral images,
        % tonemap channel as monochrome image instead of conversion to RGB
        hist_widget;
    end
    
    properties(Access = protected)
        image;
        selected_channels = [];
        parent;
        ui; % ui handles
        callback; % update displayed image(s) if the tonemapper's properties are changed
        orientation = 'horizontal';
        init_done = false;
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
                    case 'orientation'
                        obj.orientation = varargin{ii + 1};
                    otherwise
                        error('tonemapper:unsupported_argument', ...
                            'unknown parameter name %s', varargin{ii});
                end
            end
        end
        
        function im = tonemap(obj, im, varargin)
            if ~exist('im', 'var')
                im = obj.image;
            end
            
            was_img = isa(im, 'img');
            if ~was_img
                im = img(im);
            end
            
            if ~isempty(obj.selected_channels)
                im = im(:, :, obj.selected_channels);
                if ~isempty(varargin)
                    for ii = 1 : 2 : numel(varargin)
                        if ischar(varargin{ii}) && strcmpi(varargin{ii}, 'rgb_mat')
                            varargin{ii + 1} = varargin{ii + 1}(:, obj.selected_channels);
                        end
                    end
                end
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
            obj.callback();
        end
        
        function callback_image_changed(obj, im)
            % update UI
            obj.image = im;
            
            if ~isa(obj.image, 'img')
                obj.image = img(obj.image);
            end
            
            % ensure channel selection agrees with the channels of the new
            % image
            if ~isempty(obj.selected_channels)
                obj.selected_channels(obj.selected_channels > obj.image.nc) = [];
            end
            
            obj.populate_channel_list();
            if obj.image.is_spectral()
                im = obj.image.to_rgb();
            else
                im = obj.image;
            end
            obj.hist_widget.update(im);
        end
        
        function select_channels(obj, selection)
            assert(isnumeric(selection) && (isempty(selection) || ...
                1 <= min(selection) && max(selection) <= obj.image.num_channels), ...
                'channel selection must be array of indices into the image''s channels.');
            obj.selected_channels = sort(selection(:));
            % ensure channel selection agrees with the channels of the new
            % image
            if ~isempty(obj.selected_channels)
                obj.selected_channels(obj.selected_channels > obj.image.nc) = [];
            end
            
            obj.hist_widget.update(obj.image(:, :, obj.selected_channels));
            
            % update UI
            obj.ui.lb_channels.Value = obj.selected_channels;
        end
        
        function selection = get_selected_channels(obj)
            selection = 1;
            if isempty(obj.selected_channels)
                if ~isempty(obj.image)
                    selection = 1 : obj.image.num_channels;
                end
            else
                selection = obj.selected_channels;
            end
        end
    end
    
    methods(Access = protected)
        function im = tonemap_simple(obj, im, varargin)
            % given an image with arbitrarily high dynamic range and
            % potentially multispectral data, this method converts to RGB
            % and reduces the dynamic range by offsetting, scaling and
            % gamma correction; by default, the resulting image is clamped
            % to [0, 1]
            
            if ~isempty(varargin)
                assert(iscell(varargin), ...
                    'parameters must be specified as name-value pairs.');
                for ii = 1 : numel(varargin)
                    if ischar(varargin{ii})
                        switch lower(varargin{ii})
                            case 'rgb_mat'
                                rgb_mat = varargin{ii + 1};
                        end
                    end
                end
            end
            
            % deal with channel numbers ~= 3
            if im.nc == 1 && obj.raw_mode || im.is_monochrome()
                im = repmat(im, 1, 1, 3);
            elseif im.is_spectral()
                if exist('rgb_mat', 'var')
                    % custom RGB conversion matrix
                    im = im.to_rgb(rgb_mat);
                else
                    im = im.to_rgb();
                end
            elseif im.nc ~= 3
                error('tonemapper:unsupported_channels', ...
                    'unsupported number of channels (%d).', im.nc);
            end
            
            % todo: allow mapping negative values with gamma
            im = obj.scale * tb.clamp(im - obj.offset, 0, inf);
            im = im .^ (1. / obj.gamma);
            
            if obj.clamp
                im = tb.clamp(im, 0, 1);
            end
        end
        
        function ui_layout(obj)
            % set up gui layout
            obj.ui.l0 = uigridcontainer('v0', 'Parent', obj.parent', ...
                'Units', 'normalized', 'Position', [0, 0, 1, 1], ...
                'GridSize', [3, 1], 'SizeChangedFcn', @obj.callback_resize);
            
            % top part of UI (scale, offset, ...)
            obj.ui.l1_top = uigridcontainer('v0', 'Parent', obj.ui.l0, ...
                'Units', 'normalized', 'Position', [0, 0, 1, 1], ...
                'GridSize', [4, 2]);
            
            % middle part of UI (channel selection)
            obj.ui.l1_mid = uigridcontainer('v0', 'Parent', obj.ui.l0, ...
                'Units', 'normalized', 'Position', [0, 0, 1, 1], ...
                'GridSize', [2, 1]);
            
            % bottom part of UI (histogram widget)
            obj.ui.l1_bot = uipanel('Parent', obj.ui.l0, ...
                'Units', 'normalized', 'Position', [0, 0, 1, 1]);
        end
        
        function ui_initialize(obj)
            obj.init_done = false;
%             % assigned image
%             obj.ui.label_assigned = uicontrol('Parent', obj.ui.l1_top, ...
%                 'style', 'text', 'String', 'image', ...
%                 'HorizontalAlignment', 'right');
%             obj.ui.popup_assigned = uicontrol('Parent', obj.ui.l1_top, ...
%                 'style', 'popupmenu', 'String', {''}, ...
%                 'Value', 1, 'Callback', @obj.callback_ui);
            
            % method
            obj.ui.label_method = uicontrol('Parent', obj.ui.l1_top, ...
                'style', 'text', 'String', 'method', ...
                'HorizontalAlignment', 'right');
            obj.ui.popup_method = uicontrol('Parent', obj.ui.l1_top, ...
                'style', 'popupmenu', 'String', {'simple'}, ...
                'Value', 1, 'Callback', @obj.callback_ui);
            
            % scale
            obj.ui.label_scale = uicontrol('Parent', obj.ui.l1_top, ...
                'style', 'text', 'String', 'scale', ...
                'HorizontalAlignment', 'right');
            obj.ui.edit_scale = uicontrol('Parent', obj.ui.l1_top, ...
                'style', 'edit', 'String', num2str(obj.scale), ...
                'Callback', @obj.callback_ui);
            
            % offset
            obj.ui.label_offset = uicontrol('Parent', obj.ui.l1_top, ...
                'style', 'text', 'String', 'offset', ...
                'HorizontalAlignment', 'right');
            obj.ui.edit_offset = uicontrol('Parent', obj.ui.l1_top, ...
                'style', 'edit', 'String', num2str(obj.offset), ...
                'Callback', @obj.callback_ui);
            
            % gamma
            obj.ui.label_gamma = uicontrol('Parent', obj.ui.l1_top, ...
                'style', 'text', 'String', 'gamma', ...
                'HorizontalAlignment', 'right');
            obj.ui.edit_gamma = uicontrol('Parent', obj.ui.l1_top, ...
                'style', 'edit', 'String', num2str(obj.gamma), ...
                'Callback', @obj.callback_ui);
            
            % create channel list
            obj.ui.uip_channels = uipanel(obj.ui.l1_mid, 'Title', 'Channels');
            obj.ui.lb_channels = uicontrol('Parent', obj.ui.uip_channels, ...
                'Units', 'normalized', 'Position', [0, 0, 1, 1], ...
                'Style', 'listbox', 'Min', 0, 'Max', 2, 'Callback', @obj.callback_ui, ...
                'FontSize', 6);
            obj.ui.cb_raw_mode = uicontrol(obj.ui.l1_mid, 'Units', 'normalized', ...
                'Position', [0, 0, 1, 1], 'Style', 'checkbox', 'Value', obj.raw_mode, ...
                'String', 'raw mode', 'Callback', @obj.callback_ui);
            obj.ui.l1_mid.VerticalWeight = [0.9, 0.1];
            obj.populate_channel_list();
            
            % create histogram widget
            obj.hist_widget = hist_widget(obj.ui.l1_bot, ...
                'orientation', 'vertical', ...
                'callback', @obj.callback_hist_widget); %#ok<CPROP>
            
            obj.init_done = true;
            obj.callback_resize();
        end
        
        function populate_channel_list(obj)
            % get channel names of currently assigned image
            if ~isempty(obj.image)
                chan_names = obj.image.channel_names;
                empty = cellfun(@isempty, chan_names);
                ch_inds = 1 : obj.image.nc;
                chan_names(empty) = cellfun(@(x) sprintf('ch%03d', x), ...
                    num2cell(ch_inds(empty)), 'UniformOutput', false);
                obj.ui.lb_channels.String = chan_names;
            end
        end
        
        function callback_hist_widget(obj, lower, upper)
            obj.scale = 1 ./ (upper - lower);
            obj.offset = lower;
            obj.ui.edit_scale.String = num2str(obj.scale);
            obj.ui.edit_offset.String = num2str(obj.offset);
            obj.update();
        end
        
        function callback_ui(obj, src, evnt) %#ok<INUSD>
            if src == obj.ui.edit_scale
                % scale
                try
                    obj.scale = str2double(src.String);
                catch
                    src.String = num2str(obj.scale);
                end
            elseif src == obj.ui.edit_offset
                % offset
                try
                    obj.offset = str2double(src.String);
                catch
                    src.String = num2str(obj.offset);
                end
            elseif src == obj.ui.edit_gamma
                % gamma
                try
                    obj.gamma = str2double(src.String);
                catch
                    src.String = num2str(obj.gamma);
                end
            elseif src == obj.ui.popup_method
                % TODO
            elseif src == obj.ui.lb_channels
                % channels
                obj.selected_channels = src.Value;
                
                obj.hist_widget.update(obj.image(:, :, obj.selected_channels));
                
                if numel(obj.selected_channels) == 1
                    obj.ui.cb_raw_mode.Enable = 'on';
                else
                    obj.ui.cb_raw_mode.Enable = 'off';
                end
            elseif src == obj.ui.cb_raw_mode
                % raw mode
                obj.raw_mode = src.Value;
            end
            
            if ~isempty(obj.callback)
                obj.callback();
            end
        end
        
        function callback_resize(obj, src, evnt) %#ok<INUSD>
            % gui layout
            if obj.init_done
                % set up l0 weights
                units = obj.ui.l0.Units;
                obj.ui.l0.Units = 'pixels';
                pos = obj.ui.l0.Position;
                obj.ui.l0.Units = units;
                
                h = pos(4);
                h1 = 20 * 4 + 5 * obj.ui.l1_top.Margin + 1 * obj.ui.l0.Margin;
                h2 = max(1, (h - h1) / 2);
                h3 = max(1, (h - h1 - h2));
                obj.ui.l0.VerticalWeight = [h1, h2, h3];
                
                units = obj.ui.l1_top.Units;
                obj.ui.l1_top.Units = 'pixels';
                pos = obj.ui.l1_top.Position;
                obj.ui.l1_top.Units = units;
                
                w = pos(3) - 3 * obj.ui.l0.Margin;
                h = pos(4) - 6 * obj.ui.l0.Margin;
                
                obj.ui.l1_top.HorizontalWeight = [60, max(1, w - 60)];
                obj.ui.l1_top.VerticalWeight = [20, 20, 20, 20];
            end
        end
    end
end
