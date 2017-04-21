% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-03-06
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
% Slider with two knobs, allowing to select a range.
classdef range_slider < handle
    properties(Access = protected, Constant)
        default_slider_min = 0;
        default_slider_max = 10000;
        default_slider_low = 1000;
        default_slider_high = 9000;
        default_position = [1, 1, 100, 63];
        default_orientation = 'horizontal';
    end
    
    properties(Access = public)
        slider;
        slider_handle;
        container;
    end
        
    properties(Access = protected)
        uip;
        lower = 0.25;
        higher = 0.75;
        minimum = 0;
        maximum = 1;
        
        is_horizontal = true;
        
        callback_changed;
    end
    
    methods(Access = public)
        function obj = range_slider(parent, varargin)
            if ~exist('parent', 'var') || isempty(parent)
                parent = figure();
            end
            
            obj.uip = uigridcontainer('v0', 'Parent', parent);
            obj.uip.Units = 'pixels';
            slider_position = obj.uip.Position;
            obj.uip.Units = 'normalized';
            
            p = inputParser;
            p.CaseSensitive = false;
            p.KeepUnmatched = true;
            p.addOptional('min', obj.minimum);
            p.addOptional('max', obj.maximum);
            p.addOptional('low', obj.lower);
            p.addOptional('high', obj.higher);
            p.addOptional('Callback', @obj.default_callback_changed);
            p.addOptional('Orientation', obj.default_orientation, ...
                @(x) any(strcmpi(x, {'horizontal', 'vertical'})));
            p.addOptional('Position', slider_position);
            p.addOptional('Units', 'normalized');
            p.parse(varargin{:});
            unmatched = struct2cell(p.Unmatched);
            
            obj.slider = com.jidesoft.swing.RangeSlider(...
                obj.default_slider_min, obj.default_slider_max, ...
                obj.default_slider_low, obj.default_slider_high);
            obj.slider_handle = handle(obj.slider, 'CallbackProperties');
            [obj.slider, obj.container] = javacomponent(obj.slider, ...
                p.Results.Position, obj.uip);
            
            % properly set position
            obj.container.Units = p.Results.Units;
            obj.container.Position = p.Results.Position;
            
            obj.lower = p.Results.low;
            obj.higher = p.Results.high;
            obj.minimum = p.Results.min;
            obj.maximum = p.Results.max;
            obj.slider.setMinimum(obj.real_to_slider(obj.minimum));
            obj.slider.setMaximum(obj.real_to_slider(obj.maximum));
            obj.slider.setLowValue(obj.real_to_slider(obj.lower));
            obj.slider.setHighValue(obj.real_to_slider(obj.higher));
            
            obj.is_horizontal = strcmpi(p.Results.Orientation, 'horizontal');
            if ~obj.is_horizontal
                obj.slider.setOrientation(1);
            end
            
            obj.slider.MinorTickSpacing = obj.range_internal() / 100;
            obj.slider.MajorTickSpacing = obj.range_internal() / 10;
            drawnow;
            obj.update_labels();
            obj.slider.PaintLabels = true;
            obj.slider.PaintTicks = true;

            obj.slider.StateChangedCallback = @obj.callback_internal;
            obj.slider.MouseWheelMovedCallback = @obj.callback_internal;
            obj.uip.SizeChangedFcn = @obj.callback_resize;
            obj.callback_changed = p.Results.Callback;
            
            if ~isempty(unmatched)
                set(obj.slider, unmatched{:});
            end
        end
        
        function r = range(obj)
            r = obj.maximum - obj.minimum;
        end
        
        function set_minimum(obj, minimum)
            obj.minimum = minimum;
            if obj.minimum == obj.maximum
                % ensure nonzero range
                obj.maximum = obj.maximum + obj.eps_internal();
            end
            obj.update_labels();
        end
        
        function set_maximum(obj, maximum)
            obj.maximum = maximum;
            if obj.minimum == obj.maximum
                % ensure nonzero range
                obj.maximum = obj.maximum + obj.eps_internal();
            end
            obj.update_labels();
        end
        
        function siz = MinimumSize(obj)
            siz = [obj.slider.MinimumSize.width, obj.slider.MinimumSize.height];
        end
    end
       
    methods(Access = protected)
        function range = range_internal(obj)
            range = obj.slider.Maximum - obj.slider.Minimum;
        end
        
        function eps = eps_internal(obj)
            eps = 1 / obj.range_internal;
        end
        
        function update_labels(obj)
            hash_table = java.util.Hashtable();
            major_tick_spacing = obj.range_internal() / 5;
            
            % compute number of digits that we can afford for one label
            num_digits = ceil(obj.slider.getSize.width / 10); % assume fixed font @ 8p
            if obj.is_horizontal
                num_digits = ceil(num_digits / 10) - 2;
            end
            
            leading_necessary = max(0, ceil(log10(obj.slider_to_real(obj.slider.Maximum))));
            dec_necessary = max(0, ceil(-log10(obj.range() / 10)));
            
            digits_leading = min(num_digits, leading_necessary);
            digits_decimal = max(0, min(dec_necessary, num_digits - digits_leading));
            
            for pos = obj.slider.Minimum : major_tick_spacing : obj.slider.Maximum
                hash_table.put(int32(pos), javax.swing.JLabel(sprintf(['%', num2str(digits_leading), ...
                    '.', num2str(digits_decimal), 'f'], obj.slider_to_real(pos))));
            end
            obj.slider.setLabelTable(hash_table);
        end
        
        function callback_resize(obj, src, evnt)
            obj.update_labels();
        end
        
        function value = slider_to_real(obj, slider_value)
            value = obj.minimum + obj.range() .* slider_value ./ obj.range_internal();
        end
        
        function slider_value = real_to_slider(obj, value)
            slider_value = (value - obj.minimum) .* obj.range_internal() ./ obj.range();
        end
        
        function callback_internal(obj, src, evnt, varargin)
            if isa(evnt, 'java.awt.event.MouseWheelEvent')
                if evnt.getWheelRotation() > 0
                    src.Minimum = src.Minimum - obj.range_internal() / 100;
                    src.Maximum = src.Maximum + obj.range_internal() / 100;
                else
                    src.Minimum = src.Minimum + obj.range_internal() / 100;
                    src.Maximum = src.Maximum - obj.range_internal() / 100;
                end
                obj.update_labels();
            else
                low = src.Value;
                high = src.Value + src.Extent;
                obj.lower = obj.slider_to_real(low);
                obj.higher = obj.slider_to_real(high);
                
                obj.callback_changed(obj.lower, obj.higher);
            end
        end
        
        function default_callback_changed(obj, lower, higher)
            disp([lower, higher]);
        end
    end
end
