% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-01-09
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
% Rudimentary image viewer class.
classdef iv < handle    
    properties(Access = public)
        figure_handle;
        parent_handle;
        axes_handle;
        zoomaxes_handle;
        image_handle;
        
        images; % cell array of img objects
        
        tonemapper; % map image data to a range that allows for display
    end
    
    properties(Access = protected)
        ui; % struct storing all layout handles
        selected_image = 1;
        selected_frame = 1;
        
        old_callback_key_press;
        old_callback_key_release;
        old_callback_scroll;
        
        key_mods = {};
    end
    
    properties(Constant)
        slider_height = 65;
        left_width = 200;
    end
    
    methods(Access = public)
        function obj = iv(varargin)
            if iscell(varargin{1})
                % all input images are provided in a cell array
                if all(cellfun(@isnumeric, varargin{1}))
                    varargin{1} = cellfun(@(x) img(x), varargin{1}, ...
                        'UniformOutput', false);
                end
                varargin = [varargin{1}(:)', varargin(2 : end)];
            else
                % convert non-image numeric ND-arrays (2 <= N <= 4) to
                % img objects 
                
                % only convert those inputs that come before the first
                % string argument to avoid converting values of
                % parameter-value pairs
                first_char_arg = find(cellfun(@ischar, varargin), 1);
                im_mat_inds = cellfun(@(input) isnumeric(input) && ndims(input) >= 2 ...
                    && ndims(input) <= 4, varargin);
                im_mat_inds = find(im_mat_inds);
                im_mat_inds(im_mat_inds > first_char_arg) = [];
                varargin(im_mat_inds) = cfun(@(im) img(im), varargin(im_mat_inds));
            end
            
            % grab all inputs that are img objects
            img_inds = cellfun(@(x) isa(x, 'img'), varargin);
            obj.images = varargin(img_inds);
            varargin = varargin(~img_inds);
            
            % parse inputs & set / create handles
            [varargin, parent] = arg(varargin, 'parent', [], false);
            if ~isempty(varargin)
                unmatched = varargin(cellfun(@ischar, varargin));
                unmatched = sprintf('%s, ', unmatched{:});
                unmatched = unmatched(1 : end - 2);
                if isempty(unmatched)
                    classes = cfun(@(arg) class(arg), varargin);
                    classes = sprintf('%s, ', classes{:});
                    classes = classes(1 : end - 2);
                    error('iv:unknown_input', ['unsupported input(s) of class: ', ...
                        classes]);
                else
                    error('iv:unsupported_parameter', ...
                        ['unkown parameter name(s): ', unmatched]);
                end
            end
            if isempty(parent)
                parent = figure();
                parent = axes(parent);
            end
            [obj.figure_handle, obj.parent_handle, obj.axes_handle] = ...
                tb.get_parent(parent);
            
            % enable mouse interactivity (zoom & pan) by default
            if ~isempty(obj.axes_handle)
                obj.zoomaxes_handle = zoomaxes(obj.axes_handle);
            else
                obj.zoomaxes_handle = zoomaxes();
                obj.axes_handle = obj.zoomaxes_handle.ah;
            end
            
            obj.old_callback_key_press = obj.figure_handle.WindowKeyPressFcn;
            obj.old_callback_key_release = obj.figure_handle.WindowKeyReleaseFcn;
            obj.old_callback_scroll = obj.figure_handle.WindowScrollWheelFcn;
            obj.figure_handle.WindowScrollWheelFcn = @obj.callback_scroll;
            obj.figure_handle.WindowKeyPressFcn = @obj.callback_key_press;
            obj.figure_handle.WindowKeyReleaseFcn = @obj.callback_key_release;
            
            obj.ui_layout();
            obj.ui_initialize();
            
            obj.tonemapper = tonemapper('callback', @obj.paint);
            obj.tonemapper.create_ui(obj.ui.l1_left_tab_tm);
            
            obj.ui_layout_finalize();
            obj.axes_handle.Position = [0, 0, 1, 1];
            
            % ensure that all listeners are removed after the object is
            % destroyed
            obj.figure_handle.DeleteFcn = @obj.cleanup;
            
            obj.change_image();
            obj.paint();
            
            axis(obj.axes_handle, 'tight');
            obj.axes_handle.Clipping = 'off';
        end
        
        function delete(obj)
            obj.cleanup();
        end
        
        function cleanup(obj, varargin)
            % remove change listeners for all loaded image objects
            for ii = 1 : obj.ni
                obj.images{ii}.remove_viewer(obj);
            end
        end
        
        function paint(obj)
            % display the currently selected img object
            if isempty(obj.image_handle)
                obj.image_handle = tb.imshow2(obj.axes_handle, ...
                    obj.tonemapper.tonemap());
            else
                obj.image_handle = tb.imshow2(obj.image_handle, ...
                    obj.tonemapper.tonemap());
            end
        end
        
        function change_image(obj)
            % update UI if another image was selected
            for ii = 1 : obj.ni
                obj.images{ii}.remove_viewer(obj);
            end
            [im, im_comp] = obj.cur_img();
            im.add_viewer(obj);
            if ~isempty(im_comp)
                im_comp.add_viewer(obj);
            end
            
            obj.tonemapper.callback_image_changed(im);
            
            obj.update_comparison_ui();
            
            % show frame selection if multiple frames are present
            if obj.nf() > 1
                obj.ui.container_frames.Visible = 'on';
                obj.ui.slider_frames.set_maximum(obj.nf());
                obj.ui.slider_frames.set_major_tick_spacing(min(5, round(obj.nf() / 10)));
            else
                obj.ui.container_frames.Visible = 'off';
            end
        end
        
        function [im1, im2] = cur_img(obj)
            % return the currently selected img object
            im1 = obj.images{obj.selected_image(1)};
            im2 = [];
            if numel(obj.selected_image) == 2
                im2 = obj.images{obj.selected_image(2)};
            end
        end
        
        function im = cur_frame(obj)
            % return the currently selected frame from the currently
            % selected img object
            im = obj.images{obj.selected_image}(:, :, :, obj.selected_frame);
        end
        
        function selection = get_selection(obj, inds) %#ok<INUSD>
            inds = default('inds', 1);
            selection = obj.selected_image(inds);
        end
        
        function n = nf(obj)
            % return the total number of frames in the currently selected
            % img object
            n = obj.images{obj.selected_image(1)}.nf;
        end
        
        function n = ni(obj)
            % return the total number of images
            n = numel(obj.images);
        end
        
        function axes_handle = getAxes(obj)
            axes_handle = obj.axes_handle;
        end
        
        function figure_handle = getFigure(obj)
            figure_handle = obj.figure_handle;
        end
        
        function parent_handle = getParent(obj)
            parent_handle = obj.parent_handle;
        end
        
        function image_handle = getImageHandle(obj)
            image_handle = obj.image_handle;
        end
        
        function rgb = tonemap(obj, im)
            rgb = obj.tonemapper.tonemap(im);
        end
    end
    
    methods(Access = protected)
        function ui_layout(obj)
            obj.ui.l0 = uix.HBoxFlex('Parent', obj.parent_handle, 'Spacing', 5);
            obj.ui.l1_left_tabs = uix.TabPanel('Parent', obj.ui.l0);
            obj.ui.l1_left_tab_tm = uipanel(obj.ui.l1_left_tabs, 'Title', 'Tonemapping');
            obj.ui.l2_left_grid_is = uix.VBox('Parent', obj.ui.l1_left_tabs);
            obj.ui.uip_selection = uipanel('Parent', obj.ui.l2_left_grid_is, ...
                'Title', 'Selection');
            obj.ui.uip_comparison = uipanel('Parent', obj.ui.l2_left_grid_is, ...
                'Title', 'Comparison', 'Visible', 'off');
            obj.ui.l3_comparison = uix.Grid('Parent', obj.ui.uip_comparison);
            obj.ui.l1_right = uix.VBox('Parent', obj.ui.l0);
        end
        
        function ui_layout_finalize(obj)
            % hide sliders if they're not needed
            if numel(obj.images) == 1
                obj.ui.container_image_slider.Visible = 'off';
                if obj.nf() > 1
                    obj.ui.l1_right.Heights = [0, -1, obj.slider_height];
                else
                    obj.ui.l1_right.Heights = [0, -1, 0];
                    obj.ui.container_frames.Visible = 'off';
                end
            else
                if obj.nf() > 1
                    obj.ui.l1_right.Heights = [obj.slider_height, -1, obj.slider_height];
                else
                    obj.ui.l1_right.Heights = [obj.slider_height, -1, 0];
                    obj.ui.container_frames.Visible = 'off';
                end
            end
            
            obj.ui.l0.Widths = [obj.left_width, -1];
            obj.ui.l3_comparison.Widths = [75, -1];
            obj.ui.l2_left_grid_is.Heights = [-1, 0];
        end
        
        function ui_initialize(obj)
            % image selection list
            obj.ui.lb_images = uicontrol('Parent', obj.ui.uip_selection, ...
                'Style', 'listbox', 'Min', 0, 'Max', 2, 'Callback', @obj.callback_ui, ...
                'FontSize', 6, 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
            obj.populate_image_list();
            
            % image comparison UI
            obj.ui.label_comparison_method = uicontrol('Parent', obj.ui.l3_comparison, ...
                'Style', 'text', 'String', 'method');
            obj.ui.label_comparison_cmap = uicontrol('Parent', obj.ui.l3_comparison, ...
                'Style', 'text', 'String', 'cmap');
            obj.ui.popup_comparison_method = uicontrol('Parent', obj.ui.l3_comparison, ...
                'Style', 'popupmenu', 'String', {'sliding', 'horzcat', 'vertcat', ...
                'A - B', 'B - A', 'abs(A - B)', 'RMSE', 'NRMSE', 'MAD'}, ...
                'Callback', @obj.callback_ui);
            obj.ui.popup_comparison_cmap = uicontrol('Parent', obj.ui.l3_comparison, ...
                'Style', 'popupmenu', 'String', {'parula', 'jet', 'hsv', 'hot', ...
                'cool', 'spring', 'summer', 'autumn', 'winter', 'gray', 'bone', ...
                'copper', 'pink', 'lines', 'colorcube', 'prism', 'flag'}, ...
                'Callback', @obj.callback_ui, 'Visible', 'on');
            
            % slider for image selection
            obj.ui.container_image_slider = uipanel(obj.ui.l1_right, 'Title', 'image selection');
            obj.ui.slider_images = jslider(obj.ui.container_image_slider, ...
                'min', 1, 'max', max(2, numel(obj.images)), 'value', 1, 'PaintTicks', true, ...
                'PaintTickLabels', true, 'MinorTickSpacing', 1, 'MajorTickSpacing', 10, ...
                'continuous', false, 'Callback', @obj.callback_slider_images, ...
                'Position', [0, 0, 1, 1], 'Units', 'normalized');
            
            % main image axes
            obj.ui.container_img = uipanel(obj.ui.l1_right);
            obj.axes_handle.Parent = obj.ui.container_img;
            
            % slider bar for frame selection
            obj.ui.container_frames = uipanel(obj.ui.l1_right, 'Title', 'Frames');
            obj.ui.slider_frames = jslider(obj.ui.container_frames, ...
                'min', 1, 'max', 2, 'value', 1, 'PaintTicks', true, ...
                'PaintTickLabels', true, 'MinorTickSpacing', 1, 'MajorTickSpacing', 10, ...
                'continuous', false, 'Callback', @obj.callback_slider_frames, ...
                'Position', [0, 0, 1, 1], 'Units', 'normalized');
        end
        
        function populate_image_list(obj)
            % get names if they are stored in the images
            im_names = cellfun(@(x) x.get_name(), obj.images, ...
                'UniformOutput', false);
            missing = cellfun(@isempty, im_names);
            im_inds = 1 : numel(obj.images);
            im_names(missing) = cellfun(@(x) sprintf('im%03d', x), ...
                num2cell(im_inds(missing)), 'UniformOutput', false);
            obj.ui.lb_images.String = im_names;
        end
        
        function update_comparison_ui(obj)
            % show comparison UI if two images are selected
            if numel(obj.selected_image) == 2
                obj.ui.uip_comparison.Visible = 'on';
                obj.ui.l2_left_grid_is.Heights = [-1, 2 * 30 + 10];
            else
                obj.ui.uip_comparison.Visible = 'off';
                obj.ui.l2_left_grid_is.Heights = [-1, 0];
            end
        end
        
        function callback_slider_images(obj, value)
            obj.selected_image = value;
            obj.ui.lb_images.Value = value;
            obj.change_image();
            obj.paint();
        end
        
        function callback_slider_frames(obj, value)
            obj.selected_frame = value;
            obj.change_image();
        end
        
        function callback_ui(obj, src, evnt) %#ok<INUSD>
            % react to image selections
            if src == obj.ui.lb_images
                sel = src.Value;
                if numel(sel) < 1
                    warning('iv:illegal_selection', 'please select one or two images only');
                    src.Value = 1;
                elseif numel(sel) > 2
                    warning('iv:illegal_selection', 'please select one or two images only');
                    src.Value = src.Value(1 : 2);
                end
                obj.selected_image = src.Value;
                obj.ui.slider_images.set_value(obj.selected_image(1));
                obj.change_image();
                obj.paint();
            elseif src == obj.ui.popup_comparison_method
                method = src.String{src.Value};
                switch method
                    case {'sliding', 'horzcat', 'vertcat'}
                        obj.ui.label_comparison_cmap.Visible = 'off';
                        obj.ui.popup_comparison_cmap.Visible = 'off';
                    otherwise
                        obj.ui.label_comparison_cmap.Visible = 'on';
                        obj.ui.popup_comparison_cmap.Visible = 'on';
                end
            elseif src == obj.ui.popup_comparison_cmap
                src.Value
            end
        end
        
        function add_image(obj, var_name)
            % add an image from the base workspace to the list of images
            obj.images{end + 1} = evalin('base', var_name);
            obj.populate_image_list();
        end
        
        function callback_key_press(obj, src, evnt)
            obj.key_mods = union(obj.key_mods, {evnt.Key});
            
            shift = any(ismember(obj.key_mods, {'shift'}));
            
            switch evnt.Key
                case 'a'
                    obj.tonemapper.autoScale(shift);
                case 'g'
                    obj.tonemapper.setGamma(1);
                case 'o'
                    obj.tonemapper.setOffset(0);
                case 's'
                    obj.tonemapper.setScale(1);
            end
            
            if ~isempty(obj.old_callback_key_press)
                obj.old_callback_key_press(src, evnt);
            end
        end
        
        function callback_key_release(obj, src, evnt)
            obj.key_mods = setdiff(obj.key_mods, {evnt.Key});
            
            if ~isempty(obj.old_callback_key_release)
                obj.old_callback_key_release(src, evnt);
            end
        end
        
        function callback_scroll(obj, src, evnt)
            if in_axis(obj.figure_handle, obj.axes_handle)
                sc = evnt.VerticalScrollCount;
                if ismember(obj.key_mods, {'control'})
                    if sc < 0 % wheel up
                        obj.tonemapper.setScale(obj.tonemapper.scale * 1.1 ^ -sc);
                    else % wheel down
                        obj.tonemapper.setScale(obj.tonemapper.scale / 1.1 ^ sc);
                    end
                elseif ismember(obj.key_mods, {'shift'})
                    if sc < 0 % wheel up
                        obj.tonemapper.setGamma(obj.tonemapper.gamma * 1.1 ^ -sc);
                    else % wheel down
                        obj.tonemapper.setGamma(obj.tonemapper.gamma / 1.1 ^ sc);
                    end
                end
            end
            
            if ~isempty(obj.old_callback_scroll)
                obj.old_callback_scroll(src, evnt);
            end
        end
    end
end
