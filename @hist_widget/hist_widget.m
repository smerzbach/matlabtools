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
% Widget providing a histogram of an associated image along with a range
% slider to select the dynamic range to display.
classdef hist_widget < handle
    properties(Access = public)
    end
    
    properties(Access = protected)
        parent;
        ui;
        bins;
        counts;
        data;
        
        orientation = 'horizontal';
        callback;
        hh; % histogram handle
    end
    
    methods(Access = public)
        function obj = hist_widget(parent, varargin)
            if ~exist('parent', 'var') || isempty(parent)
                parent = figure();
            end
            
            obj.parent = parent;
            
            if ~isa(parent, 'matlab.ui.container.internal.UIContainer')
                obj.parent = uipanel('Parent', obj.parent);
            end
            if isa(obj.parent, 'matlab.ui.container.Panel')
                obj.parent.Title = 'Histogram';
            end
            
            for ii = 1 : 2 : numel(varargin)
                switch lower(varargin{ii})
                    case 'callback'
                        obj.callback = varargin{ii + 1};
                    case 'orientation'
                        if ~any(strcmpi(varargin{ii + 1}, {'horizontal', 'vertical'}))
                            error('hist_widget:orientation', ['''orientation'' ', ...
                                'must be one of ''horizontal'' or ''vertical''.']);
                        end
                        obj.orientation = lower(varargin{ii + 1});
                    otherwise
                        error('hist_widget:unsupported_param', ...
                            'unsupported paramter name %s', varargin{ii});
                end
            end
            
            obj.ui_layout();
            obj.ui_initialize();
        end
        
        function update(obj, varargin)
            obj.data = varargin{1};
            if ~isa(obj.data, 'img')
                obj.data = img(obj.data);
            end
            
            try
                delete(obj.hh)
            end
            
            obj.hh = histogram(obj.ui.axes, obj.data{:});
            
            obj.ui.slider.set_minimum(obj.data.min());
            obj.ui.slider.set_maximum(obj.data.max());
        end
        
        function set_colormap(obj, map)
            
        end
    end
    
    methods(Access = protected)
        function ui_layout(obj)
            if strcmpi(obj.orientation, 'horizontal')
                grid_size = [2, 1];
            else
                grid_size = [1, 2];
            end

            obj.ui.l0 = uigridcontainer('v0', 'Parent', obj.parent, ...
                'Units', 'normalized', 'Position', [0, 0, 1, 1], ...
                'GridSize', grid_size, 'SizeChangedFcn', @obj.callback_resize);
        end
        
        function ui_initialize(obj)
            if strcmpi(obj.orientation, 'horizontal')
                obj.ui.axes = axes('Parent', obj.ui.l0, 'Position', [0, 0.5, 1, 0.5], ...
                    'XTickLabel', [], 'YTickLabel', []);
                
                obj.ui.l1 = uipanel('Parent', obj.ui.l0, 'Title', '', 'Position', [0, 0, 1, 0.5]);
                obj.ui.slider = range_slider(obj.ui.l1, 'Orientation', obj.orientation, ...
                    'Position', [0, 0, 1, 1], 'Callback', @obj.callback_range_slider);
            else
                obj.ui.l1_left = uipanel('Parent', obj.ui.l0, 'Title', '', ...
                    'Position', [0, 0, 0.5, 1], 'BorderWidth', 0);
                obj.ui.l1_right = uipanel('Parent', obj.ui.l0, 'Title', '', ...
                    'Position', [0.5, 0, 0.5, 1], 'BorderWidth', 0);
                
                obj.ui.slider = range_slider(obj.ui.l1_left, 'Orientation', obj.orientation, ...
                    'Position', [0, 0, 1, 1], 'Callback', @obj.callback_range_slider, ...
                    'min', 0, 'max', 1, 'low', 0, 'high', 1);
                obj.ui.axes = axes('Parent', obj.ui.l1_right, 'Position', [0, 0, 1, 1], ...
                    'XTickLabel', [], 'YTickLabel', []);
                
                % rotate x-y axes of histogram
                view(obj.ui.axes, 90, 90);
                obj.ui.axes.XDir = 'reverse';
                hold(obj.ui.axes, 'on');
            end
            obj.ui.l0.HorizontalWeight = [1, 1];
        end
        
        function callback_resize(obj, src, evnt)
            
        end
        
        function callback_range_slider(obj, lower, upper)
            obj.callback(lower, upper);
        end
    end
end
