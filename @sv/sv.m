% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-07-30
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
% Spectral image viewer class.
%
% Usage:
% sv(spectral_image);
%
% control + mouse: plot spectra
% control + left click: permanently plot current spectrum
% right click: remove plotted spectrum
% 
% Other usage: see iv
classdef sv < handle
    properties(Constant)
        default_ui_right_width = 275;
    end
    
    properties(GetAccess = public, SetAccess = protected)
        images;
        iv;
        
        fh;
        ah_image;
        ah_spectrum;
        ah_profile;
        zah_spectrum;
        ph_spec;
        ph_averaging_area;
        lh_spectra;
    end
    
    properties(Access = protected)    
        ui;
        layout;
        
        iv_callbacks;
        
        key_mods = {};
        sel_type = {};
        
        last_selected_x = 1;
        last_selected_y = 1;
        selector_radius = 1;
        spectra = struct('im_ind', {}, 'x', {}, 'y', {}, ...
            'x_min', {}, 'x_max', {}, 'y_min', {}, 'y_max', {}, ...
            'spectrum', {}, 'color', {}, 'plot_handle', {}, ...
            'marker_handle', {}, 'text_handle', {}, 'wls', {});
        spec_counter = 0;
        
        ui_right_width;
        
        old_callback_mouse_down;
        old_callback_mouse_up;
        old_callback_motion;
        old_callback_wheel;
        old_callback_key_press;
        old_callback_key_release;
        
        last_save_path = '';
        
        plot_profile = false;
        profile_first = [];
        profile_second = [];
        profile_first_marker = [];
        profile_second_marker = [];
        profile_line = [];
        profile_line2 = [];
    end
    
    methods(Access = public)
        function obj = sv(varargin)
            % parse inputs & set / create handles
            first_str = find(cellfun(@ischar, varargin), 1);
            args = varargin(first_str : end);
            if ~isempty(first_str)
                varargin = varargin(1 : first_str - 1);
            end
            [args, parent] = arg(args, 'parent', [], false);
            [args, obj.ui_right_width] = arg(args, 'ui_right_width', ...
                obj.default_ui_right_width);
            [args, obj.plot_profile] = arg(args, 'plot_profile', obj.plot_profile);
            [args, obj.profile_first] = arg(args, 'profile_first', obj.profile_first);
            [args, obj.profile_second] = arg(args, 'profile_second', obj.profile_second);
            varargin = [varargin; args];
            
            if isempty(parent)
                parent = handle(figure());
                p = parent.Position;
                parent.Position = [p(1), p(2) - (800 - p(4)), 1000, 800];
                parent = handle(axes('Parent', parent));
            end
            obj.fh = tb.get_parent(parent);
            obj.ui_initialize();
            
            obj.iv = iv(varargin{:}, 'parent', obj.layout.l1_iv);
            obj.images = obj.iv.images;
            obj.finalize_layout();
            obj.ah_image = obj.iv.getAxes();
            hold(obj.ah_image, 'on');
            
            obj.old_callback_mouse_down = obj.fh.WindowButtonDownFcn;
            obj.old_callback_mouse_up = obj.fh.WindowButtonUpFcn;
            obj.old_callback_motion = obj.fh.WindowButtonMotionFcn;
            obj.old_callback_wheel = obj.fh.WindowScrollWheelFcn;
            obj.old_callback_key_press= obj.fh.WindowKeyPressFcn;
            obj.old_callback_key_release = obj.fh.WindowKeyReleaseFcn;
            
            obj.fh.WindowButtonMotionFcn = @obj.callback_mouse_motion;
            obj.fh.WindowButtonDownFcn = @obj.callback_mouse_down;
            obj.fh.WindowButtonUpFcn = @obj.callback_mouse_up;
            obj.fh.WindowScrollWheelFcn = @obj.callback_wheel;
            obj.fh.WindowKeyPressFcn = @obj.callback_key_press;
            obj.fh.WindowKeyReleaseFcn = @obj.callback_key_release;
            
            hold(obj.ah_spectrum, 'on');
            
            obj.iv.parent = obj;
        end
        
        function v = getViewer(obj)
            v = obj.iv;
        end
        
        function copy_clipboard(obj)
            % create new figure to copy the current tonemapped image to
            % clipboard for easy pasting in other applications
            fig = figure('ToolBar', 'none', 'MenuBar', 'none', 'Visible', 'off');
            ah = obj.iv.axes_handle;
            copyobj(ah, fig);
            w = diff(ah.XLim);
            h = diff(ah.YLim);
            fig.Position(3 : 4) = [w, h];
            print(fig, '-clipboard', '-dbitmap');
            delete(fig);
        end
        
        function save_image(obj)
            % save current image to file
            [filename, folder] = uiputfile(obj.last_save_path, 'Save image as', 'image_tonemapped.jpg|image_hdr.exr');
            obj.last_save_path = fullfile(folder, filename);
            
            [~, ~, ext] = fileparts(filename);
            switch lower(ext)
                case {'.jpg', '.png'}
                    imwrite(obj.iv.image_handle.CData, fullfile(folder, filename));
                case '.exr'
                    im = obj.iv.cur_img();
                    exr_write(im.cdata, fullfile(folder, filename), 'half', im.channels, 'PIZ');
                otherwise
                    error('no can do.');
            end
        end
        
        function r = get_roi(obj)
            r = obj.iv.zoomaxes_handle.ph_rect;
            if isempty(r)
                return;
            end
            r = struct('x0', round(min(r.XData)), ...
                'x1', round(max(r.XData)), ...
                'y0', round(min(r.YData)), ...
                'y1', round(max(r.YData)));
            s = sprintf('(%d : %d, %d : %d, :)', r.y0, r.y1, r.x0, r.x1);
            fprintf([s, '\n']);
            clipboard('copy', s);
            assignin('base', 'r', r);
        end
        
        function add_spectrum(obj, x, y, varargin)
            % permanently add spectrum to plot for comparison
            [varargin, width] = arg(varargin, 'width', obj.selector_radius);
            arg(varargin);
            
            [~, spec_struct] = obj.average_spectra(x, y, width);
            spec_struct.im_ind = obj.iv.get_selection(1);
            
            % add averaging region
            spec_struct.marker_handle = handle(plot(obj.ah_image, ...
                    [spec_struct.x_min - 0.5, spec_struct.x_max + 0.5, spec_struct.x_max + 0.5, ...
                    spec_struct.x_min - 0.5, spec_struct.x_min - 0.5], ...
                    [spec_struct.y_min - 0.5, spec_struct.y_min - 0.5, spec_struct.y_max + 0.5, ...
                    spec_struct.y_max + 0.5, spec_struct.y_min - 0.5], ...
                    'Color', [1, 0, 1], 'LineWidth', 2));
                
            % add text label
            spec_struct.text_handle = handle(text(...
                spec_struct.x_max + 0.5, spec_struct.y_max, num2str(obj.spec_counter + 1), ...
                'Color', [1, 0, 1], 'FontWeight', 'bold', 'Parent', obj.ah_image));
            
            if ~isempty(spec_struct.wls) && all(isnumeric(spec_struct.wls))
                spec_struct.plot_handle = handle(plot(obj.ah_spectrum, ...
                    spec_struct.wls, squeeze(spec_struct.spectrum), ...
                    'Color', spec_struct.color, 'LineWidth', 2, ...
                    'DisplayName', sprintf('%s, x = %d, y = %d, im = %03d', ...
                    spec_struct.text_handle.String, spec_struct.x_min, ...
                    spec_struct.y_min, spec_struct.im_ind)));
            else
                spec_struct.plot_handle = handle(plot(obj.ah_spectrum, ...
                    squeeze(spec_struct.spectrum), ...
                    'Color', spec_struct.color, 'LineWidth', 2, ...
                    'DisplayName', sprintf('%s, x = %d, y = %d, im = %03d', ...
                    spec_struct.text_handle.String, spec_struct.x_min, ...
                    spec_struct.y_min, spec_struct.im_ind)));
            end
            
            % set callback for removal
            spec_struct.plot_handle.ButtonDownFcn = @obj.callback_mouse_down;
            spec_struct.marker_handle.ButtonDownFcn = @obj.callback_mouse_down;
            spec_struct.text_handle.ButtonDownFcn = @obj.callback_mouse_down;
            
            obj.lh_spectra = legend(obj.ah_spectrum, '-DynamicLegend');
            
            obj.spectra(end + 1) = spec_struct;
            obj.spec_counter = obj.spec_counter + 1;
        end
        
        function [profile, profiles] = callback_profile(obj, varargin)
            % add profile line between two consecutively clicked markers,
            % image values are linearly interpolated for non-integer pixel
            % values along the line
            
            [varargin, im_inds] = arg(varargin, 'im_inds', []);
            arg(varargin);
            
            if obj.ui.cb_profile.Value == 0
                return;
            end
            
            if utils.in_axis(obj.fh, obj.ah_image)
                if isempty(obj.profile_first)
                    obj.profile_first = obj.ah_image.CurrentPoint(1, 1 : 2);
                else
                    if isempty(obj.profile_second)
                        obj.profile_second = obj.ah_image.CurrentPoint(1, 1 : 2);
                    else
                        obj.profile_first = obj.profile_second;
                        obj.profile_second = obj.ah_image.CurrentPoint(1, 1 : 2);
                    end
                end
            end

            % extract line from image via interpolation
            x0 = obj.profile_first(1);
            y0 = obj.profile_first(2);
            x1 = obj.profile_second(1);
            y1 = obj.profile_second(2);

            len = ceil(norm([y0 - y1, x0 - x1]));
            ys = linspace(y0, y1, len);
            xs = linspace(x0, x1, len);
            im = obj.iv.cur_img();
            profile = im.interp(ys, xs);
            
            if ~isempty(im_inds)
                profiles = cfun(@(im) im.interp(ys, xs), obj.iv.images(im_inds));
            end

            % add the actual profile line plot
            try
                delete(obj.profile_line2);
            end
            obj.profile_line2 = plot(obj.ah_profile, squeeze(profile));

            % annotate selected line on the image
            if ~isempty(obj.profile_first)
                try %#ok<TRYNC>
                    delete(obj.profile_first_marker);
                end
                obj.profile_first_marker = scatter(obj.ah_image, obj.profile_first(1), obj.profile_first(2), 500, 'x', 'MarkerEdgeColor', 'green', 'LineWidth', 2);
            end
            if ~isempty(obj.profile_second)
                try %#ok<TRYNC>
                    delete(obj.profile_second_marker);
                end
                obj.profile_second_marker = scatter(obj.ah_image, obj.profile_second(1), obj.profile_second(2), 500, 'x', 'MarkerEdgeColor', 'red', 'LineWidth', 2);
                try %#ok<TRYNC>
                    delete(obj.profile_line);
                end
                obj.profile_line = plot(obj.ah_image, ...
                    [obj.profile_first(1), obj.profile_second(1)], ...
                    [obj.profile_first(2), obj.profile_second(2)], ...
                    ':', 'Color', 'green', 'LineWidth', 2);
            end
        end
    end
    
    methods(Access = protected)
        function ui_initialize(obj)
            obj.layout.l0 = uiextras.HBoxFlex('Parent', obj.fh, 'Spacing', 4);
            obj.layout.l1_iv = handle(uipanel('Parent', obj.layout.l0));
            obj.layout.l1_plots = uiextras.VBoxFlex('Parent', obj.layout.l0, 'Spacing', 4);
            obj.layout.l2_spectrum = handle(uipanel('Parent', obj.layout.l1_plots));
            obj.layout.l2_profile = handle(uipanel('Parent', obj.layout.l1_plots));
            obj.layout.l2_pixel_info = uiextras.HBoxFlex('Parent', obj.layout.l1_plots);
            obj.layout.l2_options = uiextras.Grid('Parent', obj.layout.l1_plots);
            
            % axes
            obj.ah_spectrum = handle(axes('Parent', obj.layout.l2_spectrum));
            obj.zah_spectrum = zoomaxes(obj.ah_spectrum);
            obj.zah_spectrum.x_pan = false;
            obj.zah_spectrum.x_zoom = false;
            obj.ah_profile = handle(axes('Parent', obj.layout.l2_profile));
            
            % pixel info
            obj.ui.edit_pixel_info = handle(uicontrol('Parent', obj.layout.l2_pixel_info, ...
                'Style', 'edit', 'Max', 2, 'FontSize', 7, ...
                'HorizontalAlignment', 'left'));
            
            % options
            obj.layout.l3_misc = uiextras.GridFlex('Parent', obj.layout.l2_options);
            
            % selector radius
            tmp = uipair(obj.layout.l3_misc, 'horizontal', ...
                @uicontrol, {'Style', 'text', 'String', 'selector radius'}, ...
                @uispinner, {'value', obj.selector_radius, 'step_size', 1, ...
                'minimum', 0, ...
                'callback', @(value) obj.set_selector_radius(value)});
            obj.ui.spinner_selector_radius = tmp.h2;
            tmp.grid.ColumnSizes = [100, 50];
            % get obj
            obj.ui.bt_get_object = handle(uicontrol('Parent', obj.layout.l3_misc, ...
                'Style', 'pushbutton', 'String', 'get obj', 'Callback', @obj.callback_ui, ...
                'FontSize', 6, 'ToolTip', 'create viewer variable "v" in base workspace'));
            % copy to clipboard
            obj.ui.bt_clipboard = handle(uicontrol('Parent', obj.layout.l3_misc, ...
                'Style', 'pushbutton', 'String', 'copy', 'Callback', @obj.callback_ui, ...
                'FontSize', 6, 'ToolTip', 'copy tonemapped image to clipboard'));
            % profile
            obj.ui.cb_profile = uicontrol('Parent', obj.layout.l3_misc, ...
                'Style', 'checkbox', 'String', 'profile', 'Value', obj.plot_profile, ...
                'callback', @(src, evnt) obj.callback_profile());
            % get ROI
            obj.ui.bt_get_roi = handle(uicontrol('Parent', obj.layout.l3_misc, ...
                'Style', 'pushbutton', 'String', 'get ROI', 'Callback', @obj.callback_ui, ...
                'FontSize', 6, 'ToolTip', 'get currently selected ROI as variable "r" in base workspace'));
            % save image as
            obj.ui.bt_saveas = handle(uicontrol('Parent', obj.layout.l3_misc, ...
                'Style', 'pushbutton', 'String', 'save', 'Callback', @obj.callback_ui, ...
                'FontSize', 6, 'ToolTip', 'save tonemapped or HDR image'));
        end
        
        function finalize_layout(obj)
            obj.layout.l0.Sizes = [-2, obj.ui_right_width];
            
            n = numel(obj.layout.l3_misc.Children);
            nr = ceil(n / 2);
            set(obj.layout.l3_misc, 'Heights', -ones(nr, 1), 'Widths', [-1, -1]);
            
            obj.layout.l1_plots.Sizes = [-1, -1, -2, nr * 30 * numel(obj.layout.l2_options.RowSizes)];
        end
        
        function set_selector_radius(obj, value)
            % set the radius of the square for avaraging spectra
            obj.selector_radius = max(0, round(value));
            obj.average_spectra();
            obj.ui.spinner_selector_radius.set_value(obj.selector_radius);
        end
        
        function print_spectrum(obj, spectrum_struct)
            s = spectrum_struct;
            str_params = sprintf(['''DisplayName'', ''(x: [%d : %d], y: [%d : %d])'', ...\n', ...
                '''Color'', [%f, %f, %f]'], s.x_min, s.x_max, s.y_min, s.y_max, s.color);
            if isempty(s.wls)
                if numel(s.spectrum) == 1
                    str_spec = num2str(s.spectrum);
                    str_spec = [str_spec, sprintf('\n')]; %#ok<SPRINTFN>
                else
                    tmp = num2str(s.spectrum);
                    tmp = mat2cell2(tmp, 1, []);
                    tmp = [tmp(1); cfun(@(tmp) [', ', tmp], tmp(2 : end))];
                    str_spec = strcat(tmp{:});
                    str_spec = ['[', str_spec, '], ...', sprintf('\n')]; %#ok<SPRINTFN>
                end
            else
                str_spec = sprintf('%3.1f, %3.4f;\n', [s.wls(:), s.spectrum(:)]');
                str_spec = ['[', str_spec(1 : end - 2), '], ...', sprintf('\n')]; %#ok<SPRINTFN>
            end
            str = ['{', str_spec, str_params, '}'];
            obj.ui.edit_pixel_info.String = str;
        end
        
        function [spectrum, spec_struct] = average_spectra(obj, x, y, radius)
            % average all spectra in a square around position (x, y) with
            % the given radius
            if ~exist('x', 'var') || isempty(x)
                x = obj.last_selected_x;
            end
            if ~exist('y', 'var') || isempty(y)
                y = obj.last_selected_y;
            end
            if ~exist('radius', 'var') || isempty(radius)
                radius = obj.selector_radius;
            end
            
            im = obj.iv.cur_img();
            
            obj.last_selected_x = x;
            obj.last_selected_y = y;
            
            x_min = max(1, x - radius);
            x_max = min(im.width, x + radius);
            y_min = max(1, y - radius);
            y_max = min(im.height, y + radius);
            
            im_roi = im(y_min : y_max, x_min : x_max, :);
            spectrum = mean(mean(im_roi, 2), 1);
            
            obj.show_averaging_area(x_min, x_max, y_min, y_max);
            
            if nargout > 1
                im_rgb = obj.iv.tonemap(im_roi);
                im_rgb.wls = {'R', 'G', 'B'};
                color = squeeze(mean(mean(im_rgb, 2), 1));
                spec_struct = struct(...
                    'im_ind', obj.iv.get_selection(1), 'x', x, 'y', y, ...
                    'x_min', x_min, 'x_max', x_max, ...
                    'y_min', y_min, 'y_max', y_max, ...
                    'spectrum', spectrum, ...
                    'color', color, 'plot_handle', [], ...
                    'marker_handle', [], 'text_handle', [], ...
                    'wls', im_roi.wls);
            end
        end
        
        function show_averaging_area(obj, x_min, x_max, y_min, y_max)
            % highlight square that is used for averaging spectra by a pink
            % rectangle
            if isempty(obj.ph_averaging_area)
                obj.ph_averaging_area = handle(plot(obj.ah_image, ...
                    [x_min, x_max, x_max, x_min, x_min], ...
                    [y_min, y_min, y_max, y_max, y_min], ...
                    'Color', [1, 0, 1]));
            else
                obj.ph_averaging_area.XData = [x_min - 0.5, x_max + 0.5, x_max + 0.5, x_min - 0.5, x_min - 0.5];
                obj.ph_averaging_area.YData = [y_min - 0.5, y_min - 0.5, y_max + 0.5, y_max + 0.5, y_min - 0.5];
                obj.ph_averaging_area.Visible = 'on';
            end
        end
        
        function callback_ui(obj, src, evnt) %#ok<INUSD>
            if src == obj.ui.bt_get_object
                assignin('base', 'v', obj);
            elseif src == obj.ui.bt_clipboard
                obj.copy_clipboard();
            elseif src == obj.ui.bt_saveas
                obj.save_image();
            elseif src == obj.ui.bt_get_roi
                obj.get_roi();
            end
        end
        
        function callback_mouse_down(obj, src, evnt)
            % some plot object / axes clicked
            obj.sel_type = union(obj.sel_type, {obj.fh.SelectionType});
            ah = [];
            if in_axis(obj.fh, obj.ah_spectrum)
                ah = obj.ah_spectrum;
            elseif in_axis(obj.fh, obj.ah_image)
                ah = obj.ah_image;
            end
            if ~isempty(ah)
                if any(ismember({'alt'}, obj.sel_type))
                    % ctrl + click / right click -> remove spectrum plot
                    pos = ah.CurrentPoint(1, 1 : 2);
                    inside = arrayfun(@(s) all(abs([s.x, s.y] - pos) - 0.5 - ...
                        [s.x_max - s.x, s.y_max - s.y] < 0), col(obj.spectra));
                    delete([obj.spectra(inside).marker_handle]);
                    delete([obj.spectra(inside).plot_handle]);
                    delete([obj.spectra(inside).text_handle]);
                    obj.spectra(inside) = [];
                end
            end
            obj.callback_mouse_motion(src, []);
            
            if ~isempty(obj.old_callback_mouse_down)
                obj.old_callback_mouse_down(src, evnt);
            end
        end
        
        function callback_mouse_up(obj, src, evnt)
            if in_axis(obj.fh, obj.ah_image) && any(ismember({'control'}, obj.key_mods))
                % ctrl + left / right click -> add spectrum or profile (ctrl + left == right click)
                if obj.ui.cb_profile.Value == 1
                    % add profile line between two consecutively clicked
                    % markers, image values are linearly interpolated for
                    % non-integer pixel values along the line
                    obj.callback_profile();
                else
                    % add single spectrum from pixel nearest to clicked position
                    pos = obj.ah_image.CurrentPoint;
                    pos = round(pos(1, 1 : 2));
                    im = obj.iv.cur_img();
                    pos(1) = min(im.width, max(1, pos(1)));
                    pos(2) = min(im.height, max(1, pos(2)));
                    obj.add_spectrum(pos(1), pos(2));
                end
            end
            
            obj.sel_type = {};
            obj.callback_mouse_motion([], []);
            if ~isempty(obj.ph_averaging_area)
                obj.ph_averaging_area.Visible = 'off';
            end
            
            if ~isempty(obj.old_callback_mouse_up)
                obj.old_callback_mouse_up(src, evnt);
            end
        end
        
        function callback_mouse_motion(obj, src, evnt)
            if in_axis(obj.fh, obj.ah_image) && ismember('control', obj.key_mods)
                pos = obj.ah_image.CurrentPoint;
                pos = round(pos(1, 1 : 2));
                im = obj.iv.cur_img();
                pos(1) = min(im.width, max(1, pos(1)));
                pos(2) = min(im.height, max(1, pos(2)));
                if isempty(obj.sel_type)
                    % left mouse button down
                    [spectrum, spec_struct] = obj.average_spectra(pos(1), pos(2));
                    obj.print_spectrum(spec_struct);
                    if isempty(obj.ph_spec) || ~isequal(obj.ph_spec.XData, spec_struct.wls)
                        if ~isempty(obj.ph_spec)
                            delete(obj.ph_spec);
                        end
                        if im.is_spectral()
                            obj.ph_spec = handle(plot(obj.ah_spectrum, im.wls, squeeze(spectrum)));
                        else
                            obj.ph_spec = handle(plot(obj.ah_spectrum, squeeze(spectrum)));
                        end
                    else
                        obj.ph_spec.YData = squeeze(spectrum);
                    end
                elseif any(ismember(obj.sel_type, 'normal'))
                    % left mouse button down
                    
                elseif any(ismember(obj.sel_type, 'alt'))
                    % right mouse button down

                elseif any(ismember(obj.sel_type, 'extend'))
                    % middle button down

                elseif any(ismember(obj.sel_type, 'open'))
                    % double click
                    
                else
                    % no button down
                end
            end
            
            if ~isempty(obj.old_callback_motion)
                obj.old_callback_motion(src, evnt);
            end
        end
        
        function callback_wheel(obj, src, evnt)
            sc = evnt.VerticalScrollCount;
            if in_axis(obj.fh, obj.ah_image) && ismember('control', obj.key_mods) && ...
                    ismember('shift', obj.key_mods)
                % ctrl + shift + wheel: change averaging radius
                obj.set_selector_radius(obj.selector_radius - sc);
                obj.callback_mouse_motion([], []);
            else
                if ~isempty(obj.old_callback_wheel)
                    obj.old_callback_wheel(src, evnt);
                end
            end
        end
        
        function callback_key_press(obj, src, evnt)
            obj.key_mods = union(obj.key_mods, {evnt.Key});
            
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
    end
end
