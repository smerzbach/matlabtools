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
    properties(Access = protected)
        figure_handle;
        parent_handle;
        axes_handle;
        image_handle;
        ui; % struct storing all layout handles
        
        images; % cell array of img objects
        selected_image = 1;
        selected_frame = 1;
        
        tonemapper; % map image data to a range that allows for display
    end
    
    properties(Constant)
        left_width = 200;
    end
    
    methods(Access = public)
        function obj = iv(varargin)
            if iscell(varargin{1})
                if all(cellfun(@isnumeric, varargin{1}))
                    varargin{1} = cellfun(@(x) img(x), varargin{1}, ...
                        'UniformOutput', false);
                end
                varargin = [varargin{1}(:), varargin(2 : end)];
            elseif all(cellfun(@isnumeric, varargin))
                varargin = cellfun(@(x) img(x), varargin, 'UniformOutput', false);
            end
            img_inds = cellfun(@(x) isa(x, 'img'), varargin);
            obj.images = varargin(img_inds);
            varargin = varargin(~img_inds);
            
            % parse inputs & set / create handles
            parent = [];
            for ii = 1 : 2 : numel(varargin)
                if strcmpi(varargin{ii}, 'Parent')
                    parent = varargin{ii + 1};
                elseif strcmpi(varargin{ii}, 'paramName')
                    
                else
                    error('iv:unsupported_parameter', ...
                        'unkown parameter name %s', varargin{ii});
                end
            end
            [obj.figure_handle, obj.parent_handle, obj.axes_handle] = ...
                tb.get_parent(parent);
            
            obj.parent_handle.SizeChangedFcn = @obj.callback_resize;
            
            obj.ui_layout();
            obj.ui_initialize();
            
            obj.tonemapper = tonemapper('callback', @obj.paint);
            obj.tonemapper.create_ui(obj.ui.l3_left_tab_tm);
            
            obj.callback_resize();
            obj.axes_handle.Position = [0, 0, 1, 1];
            
            % ensure that all listeners are removed after the object is
            % destroyed
            obj.figure_handle.DeleteFcn = @obj.cleanup;
            
            obj.change_image();
            obj.paint();
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
        
        function n = nf(obj)
            % return the total number of frames in the currently selected
            % img object
            n = obj.images{obj.selected_image(1)}.nf;
        end
        
        function n = ni(obj)
            % return the total number of images
            n = numel(obj.images);
        end
    end
    
    methods(Access = protected)
        function ui_layout(obj)
            obj.ui.l0 = uigridcontainer('v0', 'Parent', obj.parent_handle, ...
                'Units', 'normalized', 'Position', [0, 0, 1, 1], ...
                'GridSize', [1, 2]);
            obj.ui.l1_left = uiflowcontainer('v0', 'Parent', obj.ui.l0);
            obj.ui.l2_left_tabs = uitabgroup(obj.ui.l1_left, 'TabLocation', 'top');
            obj.ui.l3_left_tab_tm = uitab(obj.ui.l2_left_tabs, 'Title', 'Tonemapping');
            obj.ui.l3_left_tab_is = uitab(obj.ui.l2_left_tabs, 'Title', 'Selection');
            obj.ui.l4_left_grid_is = uigridcontainer('v0', ...
                'Parent', obj.ui.l3_left_tab_is, 'Units', 'normalized', ...
                'Position', [0, 0, 1, 1], 'GridSize', [2, 1]);
            obj.ui.l1_right = uiflowcontainer('v0', 'Parent', obj.ui.l0);
        end
        
        function ui_initialize(obj)
            % image selection list
            obj.ui.lb_images = uicontrol('Parent', obj.ui.l4_left_grid_is, ...
                'Style', 'listbox', 'Min', 0, 'Max', 2, 'Callback', @obj.callback_ui, ...
                'FontSize', 6);
            obj.populate_image_list();
            
            % image comparison UI
            obj.ui.uip_comparison = uipanel('Parent', obj.ui.l4_left_grid_is, ...
                'Title', 'Comparison', 'Visible', 'off');
            obj.ui.l5_comparison = uigridcontainer('v0', obj.ui.uip_comparison, ...
                'GridSize', [3, 2]);
            obj.ui.label_comparison_method = uicontrol('Parent', obj.ui.l5_comparison, ...
                'Style', 'text', 'String', 'method');
            obj.ui.popup_comparison_method = uicontrol('Parent', obj.ui.l5_comparison, ...
                'Style', 'popupmenu', 'String', {'sliding', 'horzcat', 'vertcat', ...
                'A - B', 'B - A', 'abs(A - B)', 'RMSE', 'NRMSE', 'MAD'}, ...
                'Callback', @obj.callback_ui);
            obj.ui.label_comparison_cmap = uicontrol('Parent', obj.ui.l5_comparison, ...
                'Style', 'text', 'String', 'cmap');
            obj.ui.popup_comparison_cmap = uicontrol('Parent', obj.ui.l5_comparison, ...
                'Style', 'popupmenu', 'String', {'parula', 'jet', 'hsv', 'hot', ...
                'cool', 'spring', 'summer', 'autumn', 'winter', 'gray', 'bone', ...
                'copper', 'pink', 'lines', 'colorcube', 'prism', 'flag'}, ...
                'Callback', @obj.callback_ui, 'Visible', 'off');
            
            % slider for image selection
            obj.ui.container_image_slider = uicontainer('Parent', obj.ui.l1_right);
            obj.ui.container_image_slider.HeightLimits = [40, 40];
            obj.ui.slider_images = jslider(obj.ui.container_image_slider, ...
                'min', 1, 'max', max(2, numel(obj.images)), 'value', 1, 'PaintTicks', true, ...
                'PaintTickLabels', true, 'MinorTickSpacing', 1, 'MajorTickSpacing', 10, ...
                'continuous', false, 'Callback', @obj.callback_slider_images, ...
                'Position', [0, 0, 1, 1], 'Units', 'normalized');
            
            if numel(obj.images) == 1
                obj.ui.container_image_slider.Visible = 'off';
            end
            
            % main image axes
            obj.ui.container_img = uicontainer('Parent', obj.ui.l1_right);
            obj.axes_handle.Parent = obj.ui.container_img;
            
            % slider bar for frame selection
            obj.ui.container_frames = uicontainer('Parent', obj.ui.l1_right);
            obj.ui.container_frames.HeightLimits = [40, 40];
            obj.ui.slider_frames = jslider(obj.ui.container_frames, ...
                'min', 1, 'max', 2, 'value', 1, 'PaintTicks', true, ...
                'PaintTickLabels', true, 'MinorTickSpacing', 1, 'MajorTickSpacing', 10, ...
                'continuous', false, 'Callback', @obj.callback_slider_frames, ...
                'Position', [0, 0, 1, 1], 'Units', 'normalized');
            
            % hide slider until it's needed
            obj.ui.container_frames.Visible = 'off';
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
            else
                obj.ui.uip_comparison.Visible = 'off';
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
        
        function callback_ui(obj, src, evnt)
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
        
        function callback_resize(obj, src, evnt) %#ok<INUSD>
            units = obj.parent_handle.Units;
            obj.parent_handle.Units = 'pixels';
            width = obj.parent_handle.Position(3);
            obj.parent_handle.Units = units;
            weights = [obj.left_width, max(1, width - obj.left_width)];
            obj.ui.l0.HorizontalWeight = weights;
            
            % optimally place slider using flow container
            if isfield(obj.ui, 'slider_frames') && strcmpi(obj.ui.container_frames.Visible, 'on')
                % we might have to flip the slider orientation
                if obj.ui.container_frames.Position(1) > obj.axes_handle.Parent.Position(1)
                    obj.ui.slider_frames.set_orientation('vertical');
                    obj.ui.container_frames.HeightLimits = [2, inf];
                    obj.ui.container_frames.WidthLimits = [40, 40];
                else
                    obj.ui.slider_frames.set_orientation('horizontal');
                    obj.ui.container_frames.WidthLimits = [2, inf];
                    obj.ui.container_frames.HeightLimits = [40, 40];
                end
            end
        end
    end
end
