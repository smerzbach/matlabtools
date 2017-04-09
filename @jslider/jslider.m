% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-03-09
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
% Wrapper around Java Swing's JSlider.
classdef jslider < handle
    properties(Access = protected, Constant)
        continuous_resolution = 10000; % number of steps that the slider internall provides
        default_position = [0, 0, 1, 1];
        default_orientation = 'horizontal';
        default_major_tick_spacing = 10;
        default_minor_tick_spacing = 10;
        default_paint_tick_labels = true;
        default_paint_ticks  = true;
    end
    
    properties(Access = public)
        slider;
        container;
    end
        
    properties(Access = protected)
        uip;
        value;
        minimum;
        maximum;
        resolution;
        continuous;
        
        is_horizontal;
        
        callback_changed;
    end
    
    methods(Access = public)
        function obj = jslider(parent, varargin)
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
            p.addOptional('value', obj.value);
            p.addOptional('continuous', true, @isscalar);
            p.addOptional('Callback', @obj.default_callback_changed);
            p.addOptional('Orientation', obj.default_orientation, ...
                @(x) any(strcmpi(x, {'horizontal', 'vertical'})));
            p.addOptional('Position', slider_position);
            p.addOptional('Units', 'normalized');
            p.addOptional('MajorTickSpacing', obj.default_major_tick_spacing);
            p.addOptional('MinorTickSpacing', obj.default_minor_tick_spacing);
            p.addOptional('PaintTickLabels', obj.default_paint_tick_labels);
            p.addOptional('PaintTicks', obj.default_paint_ticks);
            p.parse(varargin{:});
            unmatched = [fieldnames(p.Unmatched), struct2cell(p.Unmatched)]';
            unmatched = unmatched(:);
            
            obj.slider = javax.swing.JSlider;
            [obj.slider, obj.container] = javacomponent(obj.slider, p.Results.Position, obj.uip);
            
            % properly set position
            obj.container.Units = p.Results.Units;
            obj.container.Position = p.Results.Position;
            
            obj.value = p.Results.value;
            obj.minimum = p.Results.min;
            obj.maximum = p.Results.max;
            obj.continuous = p.Results.continuous;
            
            if obj.continuous
                obj.resolution = obj.continuous_resolution;
            else
                % discrete steps on slider?
                obj.resolution = obj.range();
            end
            
            assert(obj.minimum < obj.maximum, ...
                'Minimum must be strictly smaller than maximum of the slider.');
            
            % set internal slider limits
            obj.slider.setMinimum(0); % slider internal minimum is always 0
            obj.slider.setMaximum(obj.resolution);
            obj.slider.setValue(obj.real_to_slider(obj.value));
            
            obj.is_horizontal = strcmpi(p.Results.Orientation, 'horizontal');
            if ~obj.is_horizontal
                obj.slider.setOrientation(1);
            end
            
            obj.slider.MinorTickSpacing = p.Results.MinorTickSpacing;
            obj.slider.MajorTickSpacing = p.Results.MajorTickSpacing;
            drawnow;
            obj.update_labels();
            obj.slider.PaintLabels = p.Results.PaintTickLabels;
            obj.slider.PaintTicks = p.Results.PaintTicks;

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
            if obj.continuous
                obj.resolution = obj.continuous_resolution;
            else
                obj.resolution = obj.range();
            end
            obj.slider.setMaximum(obj.resolution);
            obj.update_labels();
        end
        
        function set_maximum(obj, maximum)
            obj.maximum = maximum;
            if obj.continuous
                obj.resolution = obj.continuous_resolution;
            else
                obj.resolution = obj.range();
            end
            obj.slider.setMaximum(obj.resolution);
            obj.update_labels();
        end
        
        function set_value(obj, value)
            obj.value = value;
            obj.slider.Value = obj.real_to_slider(value);
        end
        
        function set_major_tick_spacing(obj, spacing)
            obj.slider.setMajorTickSpacing(spacing);
        end
        
        function set_minor_tick_spacing(obj, spacing)
            obj.slider.setMinorTickSpacing(spacing);
        end
        
        function set_paint_labels(obj, tf)
            obj.slider.setPaintLabels(tf);
        end
        
        function set_paint_ticks(obj, tf)
            obj.slider.setPaintTicks(tf);
        end
        
        function set(obj, varargin)
            set(obj.slider, varargin{:});
        end
        
        function siz = MinimumSize(obj)
            siz = [obj.slider.MinimumSize.width, obj.slider.MinimumSize.height];
        end
        
        function set_orientation(obj, orientation)
            if strcmpi(orientation, 'horizontal')
                obj.slider.setOrientation(0);
            elseif strcmpi(orientation, 'vertical')
                obj.slider.setOrientation(1);
            else
                error('jslider:orientation', ...
                    'orientation must be one of ''horizontal'' or ''vertical''');
            end
        end
    end
       
    methods(Access = protected)
        function range = range_internal(obj)
            range = obj.slider.Maximum - obj.slider.Minimum;
            assert(range == obj.resolution);
        end
        
        function update_labels(obj)
            hash_table = java.util.Hashtable();
            major_tick_spacing = max(1, obj.range_internal() / 10);
            
            % compute number of digits that we can afford for one label
            num_digits = obj.slider.getSize.width / 10; % assume fixed font @ 8p
            if obj.is_horizontal
                num_digits = ceil(num_digits / 10) - 2;
            end
            
            leading_necessary = max(0, ceil(log10(obj.slider_to_real(obj.slider.Maximum))));
            dec_necessary = max(0, min(20, ceil(-log10(obj.range() / 10))));
            
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
                    src.setValue(src.Value + 1);
                else
                    src.setValue(src.Value - 1);
                end
            end
            obj.value = obj.slider_to_real(src.Value);
            
            obj.callback_changed(obj.value);
        end
        
        function default_callback_changed(obj, value)
            disp(value);
        end
    end
end
