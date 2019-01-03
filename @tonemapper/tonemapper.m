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
    properties(Constant)
        default_main_weight = 7 * 18;
        default_channels_weight = -1;
        default_histogram_weight = -1;
        default_as_onchange = false;
    end
    
    properties(Access = public)
        scale = 1;
        offset = 0;
        gamma = 1;
        
        autoscale_prctile = 0.1;
        
        method = 'simple';
        
        clamp = true; % clamp to [0, 1] after mapping
        raw_mode = false; % for single channel selection of spectral images,
        % tonemap channel as monochrome image instead of conversion to RGB
        hist_widget;
        update_hists = true;
        
        as_onchange;
    end
    
    properties(Access = protected)
        image;
        selected_channels = [];
        parent;
        ui; % ui handles
        callback; % update displayed image(s) if the tonemapper's properties are changed
        orientation = 'horizontal';
        init_done = false;
        
        % containers for the different UI elements
        panel_main;
        panel_channels;
        panel_histogram;
        
        font_size = 8;
        font_size_channels = 6;
        label_width = 50;
        
        ui_main_weight;
        ui_channels_weight;
        ui_histogram_weight;
    end
    
    methods(Access = public)
        function obj = tonemapper(varargin)
            assert(numel(varargin) == 0 || numel(varargin) >= 2, ...
                'input must be name value pairs.');
            
            [varargin, obj.scale] = arg(varargin, 'scale', 1, false);
            [varargin, obj.offset] = arg(varargin, 'offset', 0, false);
            [varargin, obj.gamma] = arg(varargin, 'gamma', 1, false);
            [varargin, obj.method] = arg(varargin, 'method', obj.method, false);
            [varargin, obj.callback] = arg(varargin, 'callback', obj.callback, false);
            [varargin, obj.orientation] = arg(varargin, 'orientation', obj.orientation, false);
            
            if ~isempty(varargin)
                error('tonemapper:unsupported_argument', ...
                    'unknown parameter name %s', varargin{1});
            end
            
            if ~ismember(obj.method, {'simple'})
                error('tonemapper:illegal_method', ...
                    'method must be ''simple''.');
            end
        end
        
        function im = tonemap(obj, im, varargin)
            if ~exist('im', 'var') || isempty(im)
                im = obj.image;
            end
            
            was_img = isa(im, 'img');
            if ~was_img
                im = img(im);
            end
            
            im = to_single(im.copy());
            im.remove_all_viewers();
            
            if ~isempty(obj.selected_channels)
                im = im(:, :, obj.selected_channels);
                if ~isempty(varargin)
                    for ii = 1 : 2 : numel(varargin)
                        if ischar(varargin{ii}) && strcmpi(varargin{ii}, 'rgb_mat') && ~isempty(varargin{ii + 1})
                            varargin{ii + 1} = varargin{ii + 1}(:, obj.selected_channels);
                        end
                    end
                end
            end
            
            switch obj.method
                case 'simple'
                    im = obj.tonemap_simple(im, varargin{:});
                case 'reinhard'
                    im = obj.tonemap_reinhard(im, varargin{:});
                case 'exposure'
                    im = obj.tonemap_exposure(im, varargin{:});
                otherwise
                    error('tonemapper:unsupported_method', ...
                        'unsupported tonemapping method selcte');
            end
            
            if ~was_img
                im = im.cdata;
            end
        end
        
        function handles = create_ui(obj, parent, varargin)
            if ~exist('parent', 'var') || isempty(parent)
                parent = handle(figure());
                obj.parent = handle(uipanel('Parent', obj.parent));
            end
            
            obj.parent = handle(parent);
            [varargin, obj.ui_main_weight] = arg(varargin, 'ui_main_weight', obj.default_main_weight, false);
            [varargin, obj.ui_channels_weight] = arg(varargin, 'ui_channels_weight', obj.default_channels_weight, false);
            [varargin, obj.ui_histogram_weight] = arg(varargin, 'ui_histogram_weight', obj.default_histogram_weight, false);
            [varargin, obj.panel_main] = arg(varargin, 'panel_main', [], false);
            [varargin, obj.panel_channels] = arg(varargin, 'panel_channels', [], false);
            [varargin, obj.panel_histogram] = arg(varargin, 'panel_histogram', [], false); %#ok<ASGLU>
            
            obj.ui_layout();
            obj.ui_initialize();
            obj.ui_layout_finalize();
            handles = obj.ui;
        end
        
        function update(obj)
            obj.callback();
        end
        
        function callback_image_changed(obj, im)
            % update UI
            obj.image = im.copy();
            obj.image.remove_all_viewers();
            
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
                % integers cannot be converted to RGB
                if isinteger(obj.image.cdata)
                    obj.image.to_single();
                end
                im = obj.image.to_rgb();
            else
                im = obj.image;
            end
            if obj.update_hists
                obj.hist_widget.update(im);
            end
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
        
        function setScale(obj, scale)
            obj.scale = scale;
            obj.ui.edit_scale.String = num2str(scale);
            if ~isempty(obj.callback)
                obj.callback();
            end
            obj.update_hist_widget()
        end
        
        function setGamma(obj, gamma)
            obj.gamma = gamma;
            obj.ui.edit_gamma.String = num2str(gamma);
            if ~isempty(obj.callback)
                obj.callback();
            end
            obj.update_hist_widget()
        end
        
        function setOffset(obj, offset)
            obj.offset = offset;
            obj.ui.edit_offset.String = num2str(offset);
            if ~isempty(obj.callback)
                obj.callback();
            end
            obj.update_hist_widget()
        end
        
        function setAutoScalePercentile(obj, percentile)
            % set outlier rejection percentile for auto scale
            obj.autoscale_prctile = percentile;
            obj.autoScale(true);
        end
        
        function autoScale(obj, robust) %#ok<INUSD>
            % automatically select scale and offset to match the entire
            % dynamic range to [0, 1], optionally with outlier rejection
            robust = default('robust', false);
            if isempty(obj.image)
                return;
            end
            
            channels = 1 : obj.image.nc;
            if ~isempty(obj.selected_channels)
                channels = obj.selected_channels;
            end
            values = obj.image.cdata(:, :, channels);
            
            if robust
                % discard outliers by computing percentiles
                limits = prctile(single(values(:)), ...
                    [0, 100] + [1, -1] * obj.autoscale_prctile);
            else
                % min and max as limits
                limits = single([min(values(:), [], 'omitnan'), ...
                    max(values(:), [], 'omitnan')]);
            end
            
            % ensure non-empty interval
            if limits(1) == limits(2)
                limits(2) = limits(1) + eps(limits(1));
            end
            
            obj.setScale(1 / (limits(2) - limits(1)));
            obj.setOffset(limits(1));
            
            % update hist_widget
            obj.update_hist_widget();
        end
    end
    
    methods(Access = protected)
        function im = get_displayable_img(obj, im, rgb_mat) %#ok<INUSD>
            % try to convert whatever kind of input image into a 3 channel
            % image for display
            rgb_mat = default('rgb_mat', []);
            % deal with channel numbers ~= 3
            chans = im.channel_names;
            if ~(obj.raw_mode && im.is_monochrome()) && isempty(setdiff({'R', 'G', 'B'}, chans))
                % is the image alread RGB or a subset thereof?
                im = im.to_rgb();
            elseif im.nc == 1 && obj.raw_mode || im.is_monochrome()
                % single channel image and  mode requested -> just
                % display as grayscale
                im = repmat(im, 1, 1, 3);
                im.set_channel_names('RGB');
            elseif im.is_spectral()
                % spectral images need to be converted to RGB
                % custom RGB conversion matrix
                im = im.to_rgb(rgb_mat);
            elseif im.nc ~= 3
                if isempty(setdiff(chans, {'R', 'G', 'B'}))
                    % image only has a subset of RGB as channels -> fill in
                    % the missing channels with zeroes
                    [inds_out, inds] = ismember({'R', 'G', 'B'}, im.channel_names);
                    missing = find(inds == 0);
                    im_channels = cell(1, 1, 3);
                    im_channels(inds_out) = ims2cell(im.cdata, 3);
                    im_channels(missing) = repmat({zeros(im.h, im.w, 1, im.nf, class(im.cdata))}, ...
                        1, 1, numel(missing));
                    im.cdata = cat(3, im_channels{:});
                    im.set_channel_names('RGB');
                end
                try
                    im = im.to_rgb();
                catch
                    error('tonemapper:unsupported_channels', ...
                        'unsupported number of channels (%d).', im.nc);
                end
            end
        end
        
        function im = tonemap_simple(obj, im, varargin)
            % given an image with arbitrarily high dynamic range and
            % potentially multispectral data, this method converts to RGB
            % and reduces the dynamic range by offsetting, scaling and
            % gamma correction; by default, the resulting image is clamped
            % to [0, 1]
            
            if isinteger(im)
                im.to_single();
            end
            
            [varargin, rgb_mat] = arg(varargin, 'rgb_mat', [], false); %#ok<ASGLU>
            
            % deal with channel numbers ~= 3
            im = obj.get_displayable_img(im, rgb_mat);
            
            % todo: allow mapping negative values with gamma
            im = obj.scale * clamp(im - obj.offset, 0, inf); %#ok<CPROPLC>
            im = im .^ (1. / obj.gamma);
            
            if obj.clamp
                im = im.clamp(0, 1);
            end
        end
        
        function im = tonemap_reinhard(obj, im, varargin)
            % given an image with arbitrarily high dynamic range and
            % potentially multispectral data, this method converts to RGB
            % and reduces the dynamic range by offsetting, scaling and
            % gamma correction; by default, the resulting image is clamped
            % to [0, 1]
            
            if isinteger(im)
                im.to_single();
            end
            
            [varargin, rgb_mat] = arg(varargin, 'rgb_mat', [], false); %#ok<ASGLU>
            
            % deal with channel numbers ~= 3
            im = obj.get_displayable_img(im, rgb_mat);
            
            % todo: allow mapping negative values with gamma
            im = obj.scale * clamp((im - obj.offset) ./ ((im - obj.offset) + 1), 0, inf); %#ok<CPROPLC>
            im = im .^ (1. / obj.gamma);
            
            if obj.clamp
                im = im.clamp(0, 1);
            end
        end
        
        function im = tonemap_exposure(obj, im, varargin)
            % given an image with arbitrarily high dynamic range and
            % potentially multispectral data, this method converts to RGB
            % and reduces the dynamic range by offsetting, scaling and
            % gamma correction; by default, the resulting image is clamped
            % to [0, 1]
            
            if isinteger(im)
                im.to_single();
            end
            
            [varargin, rgb_mat] = arg(varargin, 'rgb_mat', [], false); %#ok<ASGLU>
            
            % deal with channel numbers ~= 3
            im = obj.get_displayable_img(im, rgb_mat);
            
            % todo: allow mapping negative values with gamma
            im = 1 - exp(-obj.scale * clamp(im - obj.offset, 0, inf)); %#ok<CPROPLC>
            im = im .^ (1. / obj.gamma);
            
            if obj.clamp
                im = im.clamp(0, 1);
            end
        end
        
        function ui_layout(obj)
            % set up gui layout
            if ~isempty(obj.panel_main) && ~isempty(obj.panel_channels) && ~isempty(obj.panel_histogram)
                % all containers created externally
                obj.ui.l0 = obj.panel_main.Parent;
                obj.ui.l1_main = obj.panel_main;
                obj.ui.l1_channels = obj.panel_channels;
                obj.ui.l1_hist = obj.panel_histogram;
            else
                % top part of UI (scale, offset, ...)
                obj.ui.l0 = uix.VBoxFlex('Parent', obj.parent);
                obj.ui.l1_main = uix.BoxPanel('Parent', obj.ui.l0);
                % middle part of UI (channel selection)
                obj.ui.l1_channels = uix.BoxPanel('Parent', obj.ui.l0);
                % bottom part of UI (histogram widget)
                obj.ui.l1_hist = uix.BoxPanel('Parent', obj.ui.l0);
            end
            set(obj.ui.l1_main, 'Title', 'Tonemapping', 'FontSize', 7);
            set(obj.ui.l1_channels, 'Title', 'Channels', 'FontSize', 7);
            set(obj.ui.l1_hist, 'Title', 'Histogram', 'FontSize', 7);
            obj.ui.l2_main = uix.VBox('Parent', obj.ui.l1_main, 'Spacing', 2, 'Padding', 1);
            obj.ui.l2_channels = uix.VBox('Parent', obj.ui.l1_channels);
        end
        
        function ui_layout_finalize(obj)
            % finish setting up layout
            cs = obj.ui.l0.Children;
            mask = cs == obj.ui.l1_main | cs == obj.ui.l1_channels | cs == obj.ui.l1_hist;
            obj.ui.l0.Heights(mask) = [obj.ui_main_weight, obj.ui_channels_weight, obj.ui_histogram_weight];
            obj.ui.l2_channels.Heights = [-1, 18];
        end
        
        function ui_initialize(obj)
            obj.init_done = false;
%             % assigned image
%             obj.ui.label_assigned = handle(uicontrol('Parent', obj.ui.l2_main, ...
%                 'style', 'text', 'String', 'image', ...
%                 'HorizontalAlignment', 'right'));
%             obj.ui.popup_assigned = handle(uicontrol('Parent', obj.ui.l2_main, ...
%                 'style', 'popupmenu', 'String', {''}, ...
%                 'Value', 1, 'Callback', @obj.callback_ui));
            
            % method
            obj.ui.label_method = label(obj.ui.l2_main, ...
                {'String', 'method', 'Style', 'text', ...
                'FontSize', obj.font_size, 'HorizontalAlignment', 'right'}, ...
                {'style', 'popupmenu', 'String', {'simple', 'reinhard', 'exposure'}, 'Value', 1, ...
                'FontSize', obj.font_size, 'Callback', @obj.callback_ui});
            obj.ui.popup_method = obj.ui.label_method.control;
            % scale
            obj.ui.label_scale = label(obj.ui.l2_main, ...
                {'String', 'scale', 'Style', 'text', ...
                'FontSize', obj.font_size, 'HorizontalAlignment', 'right'}, ...
                {'style', 'edit', 'String', num2str(obj.scale), ...
                'FontSize', obj.font_size, 'Callback', @obj.callback_ui});
            obj.ui.edit_scale = obj.ui.label_scale.control;
            % offset
            obj.ui.label_offset = label(obj.ui.l2_main, ...
                {'String', 'offset', 'Style', 'text', ...
                'FontSize', obj.font_size, 'HorizontalAlignment', 'right'}, ...
                {'style', 'edit', 'String', num2str(obj.offset), ...
                'FontSize', obj.font_size, 'Callback', @obj.callback_ui});
            obj.ui.edit_offset = obj.ui.label_offset.control;
            % gamma
            obj.ui.label_gamma = label(obj.ui.l2_main, ...
                {'String', 'gamma', 'Style', 'text', ...
                'FontSize', obj.font_size, 'HorizontalAlignment', 'right'}, ...
                {'style', 'edit', 'String', num2str(obj.gamma), ...
                'FontSize', obj.font_size, 'Callback', @obj.callback_ui});
            obj.ui.edit_gamma = obj.ui.label_gamma.control;
            % autoscale prctile
            obj.ui.label_autoscale_prctile = label(obj.ui.l2_main, ...
                {'String', 'prctile', 'Style', 'text', ...
                'FontSize', obj.font_size, 'HorizontalAlignment', 'right'}, ...
                {'Style', 'edit', 'String', num2str(obj.autoscale_prctile), ...
                'FontSize', obj.font_size, 'Callback', @obj.callback_ui});
            obj.ui.edit_autoscale_prctile = obj.ui.label_autoscale_prctile.control;
            % auto scale
            obj.ui.l2_top = uix.HBox('Parent', obj.ui.l2_main);
            obj.ui.button_autoscale = handle(uicontrol('Parent', obj.ui.l2_top, ...
                'Style', 'pushbutton', 'String', 'autoscale', ...
                'FontSize', obj.font_size, 'Callback', @obj.callback_ui));
            obj.ui.cb_as_onChange = handle(uicontrol(obj.ui.l2_top, 'Units', 'normalized', ...
                'FontSize', obj.font_size, 'Position', [0, 0, 1, 1], 'Style', 'checkbox', 'Value', false, ...
                'String', 'onChange', 'Callback', @obj.callback_ui));
            uix.Empty('Parent', obj.ui.l2_top);
            
            labels = {obj.ui.label_method, obj.ui.label_scale, obj.ui.label_offset, ...
                obj.ui.label_gamma, obj.ui.label_autoscale_prctile};
            cfun(@(l) l.setLabelSize(obj.label_width), labels);
            
            % channels
            obj.ui.lb_channels = handle(uicontrol('Parent', obj.ui.l2_channels, ...
                'Units', 'normalized', 'Position', [0, 0, 1, 1], ...
                'Style', 'listbox', 'Min', 0, 'Max', 2, 'Callback', @obj.callback_ui, ...
                'FontSize', obj.font_size_channels));
            obj.ui.l3_channels = uix.HBox('Parent', obj.ui.l2_channels);
            obj.ui.pb_select_all = handle(uicontrol(obj.ui.l3_channels, 'Units', 'normalized', ...
                'FontSize', obj.font_size, 'Position', [0, 0, 1, 1], 'Style', 'pushbutton', ...
                'String', 'select all', 'Callback', @obj.callback_ui));
            obj.ui.cb_raw_mode = handle(uicontrol(obj.ui.l3_channels, 'Units', 'normalized', ...
                'FontSize', obj.font_size, 'Position', [0, 0, 1, 1], 'Style', 'checkbox', 'Value', obj.raw_mode, ...
                'String', 'raw mode', 'Callback', @obj.callback_ui));
            obj.populate_channel_list();
            
            % create histogram widget
            obj.hist_widget = hist_widget(obj.ui.l1_hist, ...
                'orientation', 'vertical', ...
                'callback', @obj.callback_hist_widget); %#ok<CPROP>
            
            obj.init_done = true;
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
                obj.ui.lb_channels.Value = obj.get_selected_channels();
            end
        end
        
        function callback_hist_widget(obj, lower, upper)
            % update the dynamic range display in the hist_widget
            obj.scale = 1 ./ (upper - lower);
            obj.offset = lower;
            obj.ui.edit_scale.String = num2str(obj.scale);
            obj.ui.edit_offset.String = num2str(obj.offset);
            obj.update();
        end
        
        function update_hist_widget(obj)
            % update hist_widget
            range = 1 ./ obj.scale;
            lower = obj.offset;
            upper = lower + range;
            obj.hist_widget.setLower(lower);
            obj.hist_widget.setUpper(upper);
        end
        
        function callback_ui(obj, src, evnt) %#ok<INUSD>
            if src == obj.ui.button_autoscale
                % trigger autoscale
                obj.autoScale(true);
            elseif src == obj.ui.edit_autoscale_prctile
                % change autoscale percentile
                try
                    obj.setAutoScalePercentile(str2double(src.String));
                catch
                    src.String = obj.autoscale_percentile;
                end
            elseif src == obj.ui.edit_scale
                % scale
                try
                    obj.setScale(str2double(src.String));
                catch
                    src.String = num2str(obj.scale);
                end
            elseif src == obj.ui.edit_offset
                % offset
                try
                    obj.setOffset(str2double(src.String));
                catch
                    src.String = num2str(obj.offset);
                end
            elseif src == obj.ui.edit_gamma
                % gamma
                try
                    obj.setGamma(str2double(src.String));
                catch
                    src.String = num2str(obj.gamma);
                end
            elseif src == obj.ui.popup_method
                % TODO
                obj.method = lower(src.String{src.Value});
            elseif src == obj.ui.lb_channels
                % channels
                if ~isempty(src.Value)
                    obj.selected_channels = src.Value;

                    obj.hist_widget.update(obj.image(:, :, obj.selected_channels));
                end
                
                if numel(obj.selected_channels) == 1
                    obj.ui.cb_raw_mode.Enable = 'on';
                else
                    obj.ui.cb_raw_mode.Enable = 'off';
                end
            elseif src == obj.ui.pb_select_all
                obj.selected_channels = 1 : obj.image.nc;
                obj.hist_widget.update(obj.image(:, :, obj.selected_channels));
                obj.ui.lb_channels.Value = obj.selected_channels;
                
                if numel(obj.selected_channels) == 1
                    obj.ui.cb_raw_mode.Enable = 'on';
                else
                    obj.ui.cb_raw_mode.Enable = 'off';
                end
            elseif src == obj.ui.cb_raw_mode
                % raw mode
                obj.raw_mode = src.Value;
            elseif src == obj.ui.cb_as_onChange
                % as_onchange
                obj.as_onchange = src.Value;
            end
            
            if ~isempty(obj.callback)
                obj.callback();
            end
        end
    end
end
