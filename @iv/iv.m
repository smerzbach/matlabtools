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
        
        tonemapper; % map image data to a range that allows for display
    end
    
    methods(Access = public)
        function obj = iv(varargin)
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
            
            obj.ui_layout();
            obj.ui_initialize();
            
            obj.tonemapper = tonemapper('callback', @obj.paint);
            obj.tonemapper.create_ui(obj.ui.l1_vbox_left);
            obj.ui.l0_hbox.Widths = [200, -1];
            
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
            for ii = 1 : numel(obj.images)
                obj.images{ii}.remove_viewer(obj);
            end
        end
        
        function paint(obj)
            if isempty(obj.image_handle)
                obj.image_handle = tb.imshow2(obj.axes_handle, ...
                    obj.tonemapper.tonemap(obj.images{obj.selected_image}));
            else
                obj.image_handle = tb.imshow2(obj.image_handle, ...
                    obj.tonemapper.tonemap(obj.images{obj.selected_image}));
            end
        end
        
        function change_image(obj)
            for ii = 1 : numel(obj.images)
                obj.images{ii}.remove_viewer(obj);
            end
            obj.images{obj.selected_image}.add_viewer(obj);
        end
    end
    
    methods(Access = protected)
        function ui_layout(obj)
            obj.ui.l0_hbox = uix.HBoxFlex('Parent', obj.parent_handle, 'Padding', 5);
            obj.ui.l1_vbox_left = uix.VBoxFlex('Parent', obj.ui.l0_hbox, 'Padding', 5);
            obj.ui.l1_vbox_right = uix.VBoxFlex('Parent', obj.ui.l0_hbox, 'Padding', 5);
        end
        
        function ui_initialize(obj)
            obj.ui.container = uicontainer('Parent', obj.ui.l1_vbox_right);
            obj.axes_handle.Parent = obj.ui.container;
        end
    end
end