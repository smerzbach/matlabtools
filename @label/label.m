% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-11-02
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
% Label a uicontrol by adding a text-uicontrol left or above it.
%
% Usage:
%     fh = figure();
%     l0 = uix.VBox('Parent', fh);
%     slider_label = label(l0, 'slider 1', ...
%         {'Style', 'slider', 'Callback', @(src, evnt) disp(src.Value)});
%     uix.Empty('Parent', l0);
%     l0.Heights = [20, -1];
classdef label < handle
    properties
        orientation = 'horizontal';
        parent;
        layout;
        
        control;
        text;
        control_dim = -1;
        text_dim = -1;
    end
    
    methods
        function obj = label(parent, title, control, varargin)
            [varargin, obj.orientation] = arg(varargin, 'orientation', obj.orientation, false);
            [varargin, obj.text_dim] = arg(varargin, 'text_dim', obj.text_dim, false);
            [varargin, obj.control_dim] = arg(varargin, 'control_dim', obj.control_dim, false);
            [varargin, fill] = arg(varargin, 'fill', false, false); %#ok<ASGLU>
            
            obj.parent = parent;
            
            is_horizontal = strcmp(obj.orientation, 'horizontal');
            is_vertical = strcmp(obj.orientation, 'vertical');
            if is_horizontal
                obj.layout = uix.HBox('Parent', obj.parent);
            elseif is_vertical
                obj.layout = uix.VBox('Parent', obj.parent);
            else
                error('label:invalid_input', ...
                    '''orientation'' must be ''horizontal'' or ''vertical''.');
            end
            
            if ischar(title)
                obj.text = uicontrol(obj.layout, 'Style', 'Text', 'String', title);
            elseif iscell(title)
                obj.text = uicontrol(obj.layout, title{:});
            elseif ishandle(title)
                obj.text = title;
                obj.text.Parent = obj.layout;
            else
                error('label:invalid_input', ['''title'' must be a string, ', ...
                    'a cell array of arguments to uicontrol() ', ...
                    'or an already constructed uicontrol object']);
            end
            
            if iscell(control)
                obj.control = uicontrol(obj.layout, control{:}, 'Parent', obj.layout);
            elseif ishandle(control)
                obj.control = control;
                obj.control.Parent = obj.layout;
            else
                error('label:invalid_input', ['''control'' must be ', ...
                    'a cell array of arguments to uicontrol() ', ...
                    'or an already constructed uicontrol object']);
            end
            
            if fill
                uix.Empty('Parent', obj.layout);
                if is_horizontal
                    obj.layout.Widths = [obj.text_dim, obj.control_dim, -1];
                else
                    obj.layout.Heights = [obj.text_dim, obj.control_dim, -1];
                end
            else
                if is_horizontal
                    obj.layout.Widths = [obj.text_dim, -1];
                else
                    obj.layout.Heights = [obj.text_dim, -1];
                end
            end
        end
        
        function handle = getHandle(obj)
            handle = obj.control;
        end
        
        function label_handle = getLabelHandle(obj)
            label_handle = obj.text;
        end
        
        function setLabelSize(obj, dim)
            if strcmp(obj.orientation, 'horizontal')
                obj.layout.Widths(1) = dim;
            else
                obj.layout.Heights(1) = dim;
            end
        end
        
        function setControlSize(obj, dim)
            if strcmp(obj.orientation, 'horizontal')
                obj.layout.Widths(2) = dim;
            else
                obj.layout.Heights(2) = dim;
            end
        end
    end
end
