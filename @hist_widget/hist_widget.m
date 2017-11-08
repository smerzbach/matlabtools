% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-03-10
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
% Widget providing a histogram of an associated image which allows to
% interactively select the dynamic range to display.
classdef hist_widget < handle
    properties(Access = public)
        parent;
        fh;
        ah;
        zah;
        
        lower = 0;
        upper = 1;
        
        orientation = 'horizontal';
    end
    
    properties(Access = protected)
        layout;
        ui;
        bins;
        counts;
        image;
        
        callback;
        hh; % histogram handle
        
        cursor_pos = [];
        sel_type = {};
        
        ph_rect;
        
        old_callback_mouse_down;
        old_callback_mouse_up;
        old_callback_motion;
    end
    
    methods(Access = public)
        function obj = hist_widget(parent, varargin)
            if ~exist('parent', 'var') || isempty(parent)
                parent = figure();
            end
            
            [varargin, obj.callback] = arg(varargin, 'callback', [], false);
            [varargin, obj.orientation] = arg(varargin, 'orientation', 'horizontal', false);
            
            if ~any(strcmpi(obj.orientation, {'horizontal', 'vertical'}))
                error('hist_widget:orientation', ['''orientation'' ', ...
                    'must be one of ''horizontal'' or ''vertical''.']);
            end
            
            if ~isempty(varargin)
                error('hist_widget:unsupported_param', ...
                    ['unsupported parameter name(s) ', varargin{cellfun(@ischar, varargin)}]);
            end
            
            obj.parent = parent;
            obj.ui_initialize();
            obj.fh = tb.get_parent(obj.ah);
            
            if ~isa(parent, 'matlab.ui.container.internal.UIContainer')
                obj.parent = uipanel('Parent', obj.parent);
            end
            if isa(obj.parent, 'matlab.ui.container.Panel')
                obj.parent.Title = 'Histogram';
            end
            
            obj.old_callback_mouse_down = obj.fh.WindowButtonDownFcn;
            obj.old_callback_mouse_up = obj.fh.WindowButtonUpFcn;
            obj.old_callback_motion = obj.fh.WindowButtonMotionFcn;
            
            obj.fh.WindowButtonDownFcn = @obj.callback_mouse_down;
            obj.fh.WindowButtonUpFcn = @obj.callback_mouse_up;
            obj.fh.WindowButtonMotionFcn = @obj.callback_motion;
        end
        
        function update(obj, varargin)
            obj.image = varargin{1};
            if ~isa(obj.image, 'img')
                obj.image = img(obj.image);
            end
            
            try %#ok<TRYNC>
                delete(obj.hh)
            end
            
            obj.ah.Units = 'pixels';
            if strcmpi(obj.orientation, 'horizontal')
                num_bins = max(3, obj.ah.Position(3));
            else
                num_bins = max(3, obj.ah.Position(4));
            end
            obj.ah.Units = 'normalized';
            
            [obj.counts, obj.bins] = obj.image.hist('bins', round(num_bins / 3), 'channel_wise', true);
%             obj.counts = cfun(@(c) log(c + 1), obj.counts);
            bar_width = mean(diff(obj.bins));
            bins = obj.bins(1 : end - 1) + bar_width / 2; %#ok<PROPLC>
            obj.hh = cfun(@(h) bar(obj.ah, bins, h, 1), obj.counts); %#ok<PROPLC>
            obj.hh = [obj.hh{:}];
            set(obj.hh, 'EdgeColor', 'none', 'FaceAlpha', 0.25);
        end
        
        function setLower(obj, lower)
            obj.lower = lower;
            obj.showBounds();
            obj.ui.edit_lower.String = num2str(obj.lower);
        end
        
        function setUpper(obj, upper)
            obj.upper = upper;
            obj.showBounds();
            obj.ui.edit_upper.String = num2str(obj.upper);
        end
        
        function showBounds(obj)
            ymin = obj.ah.YLim(1);
            ymax = obj.ah.YLim(2);
            if isempty(obj.ph_rect)
                hold(obj.ah, 'on');
                obj.ph_rect = patch(obj.ah, 'Faces', [1, 2, 3, 4], ...
                    'XData', [obj.lower, obj.upper, obj.upper, obj.lower], ... 
                    'YData', [ymin, ymin, ymax, ymax], 'FaceAlpha', 0.25, ...
                    'FaceColor', [0, 1, 0], 'EdgeColor', [0, 1, 0]);
            else
                set(obj.ph_rect, ...
                    'XData', [obj.lower, obj.upper, obj.upper, obj.lower, obj.lower], ...
                    'YData', [ymin, ymin, ymax, ymax, ymin]);
            end
        end
    end
    
    methods(Access = protected)
        function ui_initialize(obj)
            obj.layout.l0 = uix.VBox('Parent', obj.parent);
            obj.layout.l1_top = uix.HBox('Parent', obj.layout.l0, 'Padding', 2);
            
            % lower
            obj.ui.label_lower = label(obj.layout.l1_top, ...
                {'Style', 'text', 'String', 'lower', ...
                'FontSize', 8, 'HorizontalAlignment', 'right'}, ...
                {'Style', 'edit', 'String', num2str(obj.lower), ...
                'FontSize', 8, 'Callback', @obj.callback_ui});
            obj.ui.edit_lower = obj.ui.label_lower.control;
            % upper
            obj.ui.label_upper = label(obj.layout.l1_top, ...
                {'Style', 'text', 'String', 'upper', ...
                'FontSize', 8, 'HorizontalAlignment', 'right'}, ...
                {'Style', 'edit', 'String', num2str(obj.upper), ...
                'FontSize', 8, 'Callback', @obj.callback_ui});
            obj.ui.edit_upper = obj.ui.label_upper.control;
            
            % axes
            obj.layout.uip = uipanel(obj.layout.l0, 'BorderType', 'none');
            obj.ah = axes(obj.layout.uip, 'FontSize', 6, 'LabelFontSizeMultiplier', 1);
            obj.zah = zoomaxes(obj.ah, 'Parent', obj.layout.uip);
            obj.zah.y_zoom = false;
            obj.zah.y_pan = false;
            if strcmpi(obj.orientation, 'vertical')
                % rotate x-y axes of histogram
                view(obj.ah, 90, 90);
                obj.ah.XDir = 'reverse';
            end
            hold(obj.ah, 'on');
            obj.ah.YScale = 'log';
            
            % finalize layout
            obj.layout.l0.Heights = [18, -1];
        end
        
        function callback_mouse_down(obj, src, evnt)
            if in_axis(obj.fh, obj.ah)
                obj.sel_type = union(obj.sel_type, {obj.fh.SelectionType});
                
                if ismember('alt', obj.sel_type)
                    % right mouse down: start dragging range selector
                    obj.cursor_pos = obj.ah.CurrentPoint(1, 1 : 2);
                    obj.zah.update_limits = false;
                    obj.callback_motion(src, evnt);
                end
            end
            
            if ~isempty(obj.old_callback_mouse_down)
                obj.old_callback_mouse_down(src, evnt);
            end
        end
        
        function callback_mouse_up(obj, src, evnt)
            if ~isempty(obj.cursor_pos) && ~isempty(obj.ph_rect)
                % finish range selection
                bounds = sort([obj.ph_rect.XData(1), obj.ph_rect.XData(2)]);
                obj.callback(bounds(1), bounds(2));
            end
            
            obj.cursor_pos = [];
            obj.sel_type = setdiff(obj.sel_type, {obj.fh.SelectionType});
            obj.zah.update_limits = true;
            
            if ~isempty(obj.old_callback_mouse_up)
                obj.old_callback_mouse_up(src, evnt);
            end
        end
        
        function callback_motion(obj, src, evnt)
            if ~isempty(obj.cursor_pos) && ismember('alt', obj.sel_type)
                % right button dragged -> range selection
                p1 = obj.cursor_pos(1);
                p2 = obj.ah.CurrentPoint(1, 1);
                
                obj.setLower(min(p1, p2));
                obj.setUpper(max(p1, p2));
                obj.callback(obj.lower, obj.upper);
            end
            
            if ~isempty(obj.old_callback_motion)
                obj.old_callback_motion(src, evnt);
            end
        end
        
        function callback_ui(obj, src, evnt) %#ok<INUSD>
            if src == obj.ui.edit_lower
                % lower
                try
                    obj.setLower(str2double(src.String));
                catch
                    src.String = num2str(obj.lower);
                end
            elseif src == obj.ui.edit_upper
                % upper
                try
                    obj.setUpper(str2double(src.String));
                catch
                    src.String = num2str(obj.upper);
                end
            end
            obj.callback(obj.lower, obj.upper);
        end
    end
end
