% *************************************************************************
% * Copyright 2018 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2018-07-29
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
% Spinner control (edit box with up and down arrows).
% Important properties: value, step_size, minimum, maximum.
% Important methods: get_value(), set_value(), increment(), decrement().
%
% Syntax: uispinner(parent
% Usage example:
% fh = figure;
% p = uipanel(fh, 'Units', 'pixels', 'Position', [1, 1, 50, 30]);
% s = uispinner(p, 'value', 1, 'step_size', 2, 'minimum', 0, ...
%     'callback', @(value) disp(value));
% s.decrement();
% s.increment();
% s.get_value()
classdef uispinner < uipair & matlab.mixin.SetGet
    properties(Constant)
        default_step_size = 1;
        default_value = 0;
        default_minimum = -inf;
        default_maximum = inf;
        
        default_ui_edit_weight = -1;
        default_ui_button_weight = 20;
        default_editable = true;
    end
    
    properties(Access = protected)
        value;
        minimum;
        maximum;
        step_size;
        editable;
    end
    
    properties(Access = protected)
        uip_buttons;
        ui_edit_weight;
        ui_button_weight;
        callback;
    end
    
    methods
        function obj = uispinner(parent, varargin)
            obj = obj@uipair(parent, 'horizontal', ...
                @uicontrol, {'Style', 'edit', 'String', 0}, ...
                @uipanel, {'Title', ''});
            
            [varargin, obj.step_size] = arg(varargin, 'step_size', obj.default_step_size);
            [varargin, obj.value] = arg(varargin, 'value', obj.default_value);
            [varargin, obj.minimum] = arg(varargin, 'minimum', obj.default_minimum);
            [varargin, obj.maximum] = arg(varargin, 'maximum', obj.default_maximum);
            [varargin, obj.editable] = arg(varargin, 'editable', obj.default_editable);
            [varargin, obj.callback] = arg(varargin, 'callback', @obj.default_callback);
            [varargin, obj.ui_edit_weight] = arg(varargin, 'ui_edit_weight', obj.default_ui_edit_weight);
            [varargin, obj.ui_button_weight] = arg(varargin, 'ui_button_weight', obj.default_ui_button_weight); %#ok<ASGLU>
            
            obj.grid.Widths = [obj.ui_edit_weight, obj.ui_button_weight];
            obj.display_value();
            obj.h1.Callback = @obj.callback_ui;
            
            obj.uip_buttons = uipair(obj.h2, 'vertical', ...
                @uicontrol, {'Style', 'pushbutton', 'String', '^', 'Callback', @obj.callback_ui}, ...
                @uicontrol, {'Style', 'pushbutton', 'String', 'v', 'Callback', @obj.callback_ui});
            obj.uip_buttons.grid.Heights = [-1, -1];
        end
        
        function set.editable(obj, tf)
            obj.editable = logical(tf(1));
            obj.h1.Enable = bool2onoff(obj.editable);
        end
    end
    
    methods(Access = public)
        function value = get_value(obj)
            value = obj.value;
        end
        
        function set_value(obj, value)
            obj.value = value;
            obj.display_value();
        end
        
        function step_size = get_step_size(obj)
            step_size = obj.step_size;
        end
        
        function set_step_size(obj, step_size)
            obj.step_size = step_size;
        end
        
        function decrement(obj)
            if obj.value - obj.step_size > obj.minimum
                obj.value = obj.value - obj.step_size;
            else
                obj.value = obj.minimum;
            end
            obj.display_value();
        end
        
        function increment(obj)
            if obj.value + obj.step_size < obj.maximum
                obj.value = obj.value + obj.step_size;
            else
                obj.value = obj.maximum;
            end
            obj.display_value();
        end
    end
    
    methods(Access = protected)
        function display_value(obj)
            obj.h1.String = num2str(obj.value);
        end
        
        function callback_ui(obj, src, evnt) %#ok<INUSD>
            changed = false;
            if src == obj.uip_buttons.h1 % up
                obj.increment();
                obj.display_value();
                changed = true;
            elseif src == obj.uip_buttons.h2 % down
                obj.decrement();
                obj.display_value();
                changed = true;
            elseif src == obj.h1 % edit box
                if obj.editable
                    obj.value = str2double(obj.h1.String);
                    changed = true;
                end
            end
            if changed
                obj.callback(obj.value);
            end
        end
        
        function default_callback(obj, value) %#ok<INUSL>
            disp(value);
        end
    end
end
