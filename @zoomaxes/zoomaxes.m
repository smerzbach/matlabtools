% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-10-07
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
% Pan- and zoomable axes class. Unlike with normal axes objects, there is
% no need for switching to zoom or pan modes, as they're implemented by
% default via mouse callbacks. Existing mouse callbacks will be called
% subsequently.
%
% Usage:
% - drag with left button: pan
% - drag with right button: select region to zoom into
% - mouse wheel: zoom in or out on cursor position
%
% Examples:
% 
%   % fill figure with image
%   figure;
%   ah = axes();
%   imshow(imread('cameraman.tif'), 'Parent', ah);
%   z = zoomaxes(ah, 'Position', [0, 0, 1, 1]);
%
%   % create zoomable plot
%   figure;
%   ah = axes();
%   im = imread('cameraman.tif');
%   plot(ah, im(:, [1, 64, 128]));
%   z = zoomaxes(ah);
%   % only allow to pan and zoom horizontally
%   z.y_zoom = false;
%   z.y_pan = false;
%
classdef zoomaxes < handle
    properties
        ah; % axes handle, exposed for easy access
        fh; % parent figure handle
        zoom_factor = 1.15; % factor by which to zoom in or out
        
        x_zoom = true; % enable / disable zoom along x-axis
        y_zoom = true; % enable / disable zoom along y-axis
        x_pan = true; % enable / disable panning along x-axis
        y_pan = true; % enable / disable panning along y-axis
        
        x_stop_at_orig = true; % disallow / allow zooming out beyond the original x-limits
        y_stop_at_orig = true; % disallow / allow zooming out beyond the original y-limits
        
        old_callback_scroll; % previously set scroll wheel callback
        old_callback_button_down; % previously set mouse button down callback
        old_callback_button_up; % previously set mouse button up callback
        old_callback_motion; % previously set mouse motion callback
        old_callback_key_press; % previously set key press callback
        old_callback_key_release; % previously set key release callback
        
        xlim_orig; % original x-limits
        ylim_orig; % original y-limits
        
        update_limits = true; % should the original limits be updated if they are changed due to external events (e.g. new child added)
        dirty = false; % this is set to true when the a child has been added to the axes so that the original limits can be updated
    end
    
    properties(Access = protected)
        cursor_pos = []; % store cursor position when button goes down
        sel_type = {}; % store button type when it goes down
        key_mods = {}; % keyboard modifiers pressed?
        
        ph_rect = []; % plot handle to visualize zoom selection
    end
    
    methods
        function obj = zoomaxes(varargin)
            is_axes = cellfun(@(arg) isa(arg, 'matlab.graphics.axis.Axes'), varargin);
            if any(is_axes)
                % zoomaxes(axes_handle, ...) has been called -> convert
                % axes_handle into zoomaxes object
                obj.ah = varargin{find(is_axes, 1)};
                varargin(find(is_axes, 1)) = [];
                % all remaining arguments are supposed to be
                % parameter value pairs
                if numel(varargin)
                    set(obj.ah, varargin{:});
                end
            else
                obj.ah = axes(varargin{:});
            end
            obj.fh = tb.get_parent(obj.ah);
            
            % store original axes limits to be able to reset to them
            obj.xlim_orig = obj.ah.XLim;
            obj.ylim_orig = obj.ah.YLim;
            
            % store existing callbacks (they will be called after the
            % internal ones)
            obj.old_callback_scroll = obj.fh.WindowScrollWheelFcn;
            obj.old_callback_button_down = obj.fh.WindowButtonDownFcn;
            obj.old_callback_button_up = obj.fh.WindowButtonUpFcn;
            obj.old_callback_motion = obj.fh.WindowButtonMotionFcn;
            obj.old_callback_key_press = obj.fh.WindowKeyPressFcn;
            obj.old_callback_key_release = obj.fh.WindowKeyReleaseFcn;
            
            % set internal callbacks
            obj.fh.WindowScrollWheelFcn = @obj.callback_scroll;
            obj.fh.WindowButtonDownFcn = @obj.callback_button_down;
            obj.fh.WindowButtonUpFcn = @obj.callback_button_up;
            obj.fh.WindowButtonMotionFcn = @obj.callback_motion;
            obj.fh.WindowKeyPressFcn = @obj.callback_key_press;
            obj.fh.WindowKeyReleaseFcn = @obj.callback_key_release;
            
            % add event listeners to external changes to XLim or YLim
            addlistener(obj.ah, 'XLim', 'PostSet', @obj.callback_xlim);
            addlistener(obj.ah, 'YLim', 'PostSet', @obj.callback_ylim);
            addlistener(obj.ah, 'ChildAdded', @obj.callback_children);
            addlistener(obj.ah, 'ChildRemoved', @obj.callback_children);
        end
        
        % convenience function so we can call axis(zoomaxes_obj, ...)
        function varargout = axis(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = axis(obj.ah, varargin{:});
        end
        
        % convenience function so we can call bar(zoomaxes_obj, ...)
        function varargout = bar(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = bar(obj.ah, varargin{:});
        end
        
        % convenience function so we can call barh(zoomaxes_obj, ...)
        function varargout = barh(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = barh(obj.ah, varargin{:});
        end
        
        % convenience function so we can call bar3(zoomaxes_obj, ...)
        function varargout = bar3(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = bar3(obj.ah, varargin{:});
        end
        
        % convenience function so we can call bar3h(zoomaxes_obj, ...)
        function varargout = bar3h(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = bar3h(obj.ah, varargin{:});
        end
        
        % convenience function so we can call hold(zoomaxes_obj, ...)
        function hold(obj, varargin)
            hold(obj.ah, varargin{:});
        end
        
        % convenience function so we can call image(zoomaxes_obj, ...)
        function varargout = image(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = image(obj.ah, varargin{:});
        end
        
        % convenience function so we can call imagesc(zoomaxes_obj, ...)
        function varargout = imagesc(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = imagesc(obj.ah, varargin{:});
        end
        
        % convenience function so we can call patch(zoomaxes_obj, ...)
        function varargout = patch(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = patch(obj.ah, varargin{:});
        end
        
        % convenience function so we can call mesh(zoomaxes_obj, ...)
        function varargout = mesh(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = mesh(obj.ah, varargin{:});
        end
        
        % convenience function so we can call plot(zoomaxes_obj, ...)
        function varargout = plot(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = plot(obj.ah, varargin{:});
        end
        
        % convenience function so we can call plot3(zoomaxes_obj, ...)
        function varargout = plot3(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = plot3(obj.ah, varargin{:});
        end
        
        % convenience function so we can call quiver(zoomaxes_obj, ...)
        function varargout = quiver(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = quiver(obj.ah, varargin{:});
        end
        
        % convenience function so we can call quiver3(zoomaxes_obj, ...)
        function varargout = quiver3(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = quiver3(obj.ah, varargin{:});
        end
        
        % convenience function so we can call scatter(zoomaxes_obj, ...)
        function varargout = scatter(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = scatter(obj.ah, varargin{:});
        end
        
        % convenience function so we can call scatter3(zoomaxes_obj, ...)
        function varargout = scatter3(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = scatter3(obj.ah, varargin{:});
        end
        
        % convenience function so we can call stairs(zoomaxes_obj, ...)
        function varargout = stairs(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = stairs(obj.ah, varargin{:});
        end
        
        % convenience function so we can call stem(zoomaxes_obj, ...)
        function varargout = stem(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = stem(obj.ah, varargin{:});
        end
        
        % convenience function so we can call surface(zoomaxes_obj, ...)
        function varargout = surface(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = surface(obj.ah, varargin{:});
        end
        
        % convenience function so we can call surf(zoomaxes_obj, ...)
        function varargout = surf(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = surf(obj.ah, varargin{:});
        end
        
        % convenience function so we can call trimesh(zoomaxes_obj, ...)
        function varargout = trimesh(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = trimesh(obj.ah, varargin{:});
        end
        
        % convenience function so we can call trisurf(zoomaxes_obj, ...)
        function varargout = trisurf(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = trisurf(obj.ah, varargin{:});
        end
        
        % convenience function so we can call view(zoomaxes_obj, ...)
        function varargout = view(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = view(obj.ah, varargin{:});
        end
        
        % convenience function so we can call set(zoomaxes_obj, ...)
        function set(obj, varargin)
            set(obj.ah, varargin{:});
        end
        
        % convenience function so we can call get(zoomaxes_obj, ...)
        function varargout = get(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = get(obj.ah, varargin{:});
        end
    end
    
    methods(Access = private)
        function callback_xlim(obj, src, value) %#ok<INUSD>
            stack = dbstack();
            if obj.update_limits && all(cellfun(@(cb) all(~strcmp({stack.name}', cb)), ...
                    {'zoomaxes.callback_scroll', ...
                    'zoomaxes.callback_motion', ...
                    'zoomaxes.callback_button_down', ...
                    'zoomaxes.callback_button_up'}))
                obj.dirty = true;
            end
        end
        
        function callback_ylim(obj, src, value) %#ok<INUSD>
            stack = dbstack();
            if obj.update_limits && all(cellfun(@(cb) all(~strcmp({stack.name}', cb)), ...
                    {'zoomaxes.callback_scroll', ...
                    'zoomaxes.callback_motion', ...
                    'zoomaxes.callback_button_down', ...
                    'zoomaxes.callback_button_up'}))
                obj.dirty = true;
            end
        end
        
        function callback_children(obj, src, child_data) %#ok<INUSD>
            % called after a new child has been added or removed so that
            % the original x- and y-limits can be updated
            if obj.update_limits
                obj.dirty = true;
            end
        end
        
        function callback_scroll(obj, src, evnt)
            % react to scroll wheel events
            
            if in_axis(obj.fh, obj.ah) && isempty(obj.key_mods)
                if obj.dirty && obj.update_limits
                    % original axis limits are outdated -> reset them
                    obj.xlim_orig = obj.ah.XLim;
                    obj.ylim_orig = obj.ah.YLim;
                    obj.dirty = false;
                end

                sc = evnt.VerticalScrollCount;
                factor = obj.zoom_factor ^ sc;
            
                pos = obj.ah.CurrentPoint(1, 1 : 2);
                xlim = obj.ah.XLim;
                ylim = obj.ah.YLim;
                
                if any(isnan(pos)) || any(isinf(pos))
                    pos = [mean(xlim), mean(ylim)];
                end
                
                % compute interval lengths left, right, below and above cursor
                left = pos(1) - xlim(1);
                right = xlim(2) - pos(1);
                below = pos(2) - ylim(1);
                above = ylim(2) - pos(2);
                
                % zoom in or out
                if obj.x_zoom
                    xlim = [pos(1) - factor * left, pos(1) + factor * right];
                end
                if obj.y_zoom
                    ylim = [pos(2) - factor * below, pos(2) + factor * above];
                end
                
                if obj.x_stop_at_orig
                    xlim = [max(obj.xlim_orig(1), xlim(1)), ...
                        min(obj.xlim_orig(2), xlim(2))];
                end
                
                if obj.y_stop_at_orig
                    ylim = [max(obj.ylim_orig(1), ylim(1)), ...
                        min(obj.ylim_orig(2), ylim(2))];
                end
                
                if xlim(1) ~= xlim(2) && ylim(1) ~= ylim(2)
                    set(obj.ah, 'XLim', sort(xlim), 'YLim', sort(ylim));
                end
            end
            
            if ~isempty(obj.old_callback_scroll)
                obj.old_callback_scroll(src, evnt);
            end
        end
        
        function callback_button_down(obj, src, evnt)
            % mouse button is down
            if in_axis(obj.fh, obj.ah)
                obj.sel_type = union(obj.sel_type, {obj.fh.SelectionType});
                obj.cursor_pos = obj.ah.CurrentPoint(1, 1 : 2);
                obj.callback_motion(src, evnt);
            end
            if ~isempty(obj.old_callback_button_down)
                obj.old_callback_button_down(src, evnt);
            end
        end
        
        function callback_button_up(obj, src, evnt)
            % mouse button released
            if ismember('extend', obj.sel_type)
                % middle button was dragged -> finish zoom selection
                pos = obj.ah.CurrentPoint(1, 1 : 2);
                prev = obj.update_limits;
                obj.update_limits = false;
                obj.ph_rect.Visible = 'Off';
                obj.update_limits = prev;
                xlim = sort([obj.cursor_pos(1), pos(1)]);
                ylim = sort([obj.cursor_pos(2), pos(2)]);
                
                if obj.x_zoom
                    obj.ah.XLim = xlim;
                end
                if obj.y_zoom
                    obj.ah.YLim = ylim;
                end
            end
            
            obj.cursor_pos = [];
            obj.sel_type = setdiff(obj.sel_type, {obj.fh.SelectionType});
            
            if ~isempty(obj.old_callback_button_up)
                obj.old_callback_button_up(src, evnt);
            end
        end
        
        function callback_motion(obj, src, evnt)
            % mouse moved
            if obj.dirty && obj.update_limits
                % original axis limits are outdated -> reset them
                obj.xlim_orig = obj.ah.XLim;
                obj.ylim_orig = obj.ah.YLim;
                obj.dirty = false;
            end
            
            if in_axis(obj.fh, obj.ah)
                pos = obj.ah.CurrentPoint(1, 1 : 2);
                if ~isempty(obj.cursor_pos) && ismember('normal', obj.sel_type)
                    % left button dragged -> pan
                    x_offset = obj.cursor_pos(1) - pos(1);
                    y_offset = obj.cursor_pos(2) - pos(2);

                    if obj.x_pan
                        obj.ah.XLim = obj.ah.XLim + x_offset;
                    end
                    if obj.y_pan
                        obj.ah.YLim = obj.ah.YLim + y_offset;
                    end
                end

                if ~isempty(obj.cursor_pos) && ismember('extend', obj.sel_type)
                    % middle button dragged -> zoom selection
                    p1 = obj.cursor_pos;
                    p2 = pos;
                    prev = obj.update_limits;
                    obj.update_limits = false;
                    if isempty(obj.ph_rect)
                        hold(obj.ah, 'on');
                        obj.ph_rect = plot(obj.ah, [p1(1), p2(1), p2(1), p1(1), p1(1)], ...
                            [p1(2), p1(2), p2(2), p2(2), p1(2)], 'Color', [1, 0, 1]);
                    else
                        obj.ph_rect.Visible = 'on';
                        set(obj.ph_rect, 'XData', [p1(1), p2(1), p2(1), p1(1), p1(1)], ...
                            'YData', [p1(2), p1(2), p2(2), p2(2), p1(2)]);
                    end
                    obj.update_limits = prev;
                end

                if ismember('open', obj.sel_type)
                    % double click -> reset to original limits
                    obj.ah.XLimMode = 'auto';
                    obj.ah.YLimMode = 'auto';
                    obj.xlim_orig = obj.ah.XLim;
                    obj.ylim_orig = obj.ah.YLim;
                end
            end
            
            if ~isempty(obj.old_callback_motion)
                obj.old_callback_motion(src, evnt);
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
