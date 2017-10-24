% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-09-11
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
% Small class for specifying a region of interest (ROI) in images.
classdef roi < handle
    properties
        x_min = 1;
        y_min = 1;
        x_max = 0; % set to 0: use image width, smaller 0: x_max pixel from right boundary
        y_max = 0; % set to 0: use image height, smaller 0: y_max pixel from bottom boundary
        x_stride = 1;
        y_stride = 1;
        
        height = 0;
        width = 0;
        num_channels = 0;
    end
    
    methods
        function obj = roi(mat, im)
            % construct roi object from 2 x 2 or 2 x 3 matrix, where
            % mat = [x_min, x_stride, x_max; y_min, y_stride, y_max]
            % optionally, an image array or object can be provided that is used
            % to determine the image height and width
            
            obj.x_min = mat(1, 1);
            obj.y_min = mat(2, 1);
            obj.x_max = mat(1, end);
            obj.y_max = mat(2, end);
            if size(mat, 2) == 3
                obj.x_stride = mat(1, 2);
                obj.y_stride = mat(2, 2);
            else
                obj.x_stride = 1;
                obj.y_stride = 1;
            end
            
            if exist('im', 'var') && ~isempty(im)
                [obj.height, obj.width, obj.num_channels] = size(im);
            end
        end
        
        function setImageSize(obj, im)
            [obj.height, obj.width, obj.num_channels] = size(im);
        end
        
        function mat = getMat(obj, im)
            % return a matrix representation of the currently selected ROI
            
            % get image dimensions
            if exist('im', 'var') && ~isempty(im)
                [h, w, ~] = size(im);
            else
                h = obj.height;
                w = obj.width;
            end
            
            mat = [obj.x_min, obj.x_stride, obj.x_max;
                obj.y_min, obj.y_stride, obj.y_max];
            
            if mat(1, 3) <= 0
                mat(1, 3) = w + mat(1, 3);
            end
            
            if mat(2, 3) <= 0
                mat(2, 3) = h + mat(2, 3);
            end
        end
        
        function setXMin(obj, x_min)
            obj.x_min = x_min;
%             obj.x_max = max(obj.x_max, obj.x_min);
        end
        
        function setYMin(obj, y_min)
            obj.y_min = y_min;
%             obj.y_max = max(obj.y_max, obj.y_min);
        end
        
        function setXMax(obj, x_max)
            obj.x_max = x_max;
            obj.x_min = min(obj.x_min, obj.getXMax());
        end
        
        function setYMax(obj, y_max)
            obj.y_max = y_max;
            obj.y_min = min(obj.y_min, obj.getYMax());
        end
        
        function x_min = getXMin(obj)
            x_min = obj.x_min;
        end
        
        function x_max = getXMax(obj, im)
            % return the largest x coordinate inside of the ROI
            
            % get image width
            if exist('im', 'var') && ~isempty(im)
                [~, w, ~] = size(im);
            else
                w = obj.width;
            end
            
            if obj.x_max > 0
                x_max = obj.x_max;
            else
                % roi.x_max = 0: width, roi.x_max < 0: x_max = width - x_max
                if w == 0
                    error('roi:missing_input', ...
                        ['please provide an image so that the actual pixel ', ...
                        'coordinates can be estimated for the selected ROI']);
                end
                x_max = w + obj.x_max;
            end
        end
        
        function y_min = getYMin(obj)
            y_min = obj.y_min;
        end
        
        function y_max = getYMax(obj, im)
            % return the largest y coordinate inside of the ROI
            
            % get image height
            if exist('im', 'var') && ~isempty(im)
                [h, ~, ~] = size(im);
            else
                h = obj.height;
            end
            
            if obj.y_max > 0
                y_max = obj.y_max;
            else
                % roi.y_max = 0: height, roi.y_max < 0: y_max = height - y_max
                if h == 0
                    error('roi:missing_input', ...
                        ['please provide an image so that the actual pixel ', ...
                        'coordinates can be estimated for the selected ROI']);
                end
                y_max = h + obj.y_max;
            end
        end
        
        function [width, height] = getDims(obj, with_strides) %#ok<INUSD>
            with_strides = default('with_strides', true);
            if with_strides
                if obj.x_stride < 0
                    width = numel(obj.x_min : -obj.x_stride : obj.x_max);
                elseif obj.x_stride < 1
                    width = round(numel(obj.x_min : obj.x_max) * obj.x_stride);
                else
                    width = numel(obj.x_min : obj.x_stride : obj.x_max);
                    
                end
                
                if obj.y_stride < 0
                    height = numel(obj.y_min : -obj.y_stride : obj.y_max);
                elseif obj.y_stride < 1
                    height = round(numel(obj.y_min : obj.y_max) * obj.y_stride);
                else
                    height = numel(obj.y_min : obj.y_stride : obj.y_max);
                end
            else
                width = obj.x_max - obj.x_min + 1;
                height = obj.y_max - obj.y_min + 1;
            end
        end
        
        function patch = apply(obj, im)
            was_img = isa(im, 'img');
            
            if ~was_img
                im = img(im);
            end
            
            assert(im.height == obj.height && im.width == obj.width, ...
                'image dimensions must match the ROI dimensions!');
            
            if obj.x_stride < 0
                patch = im(obj.y_min : obj.getYMax(), obj.x_min : obj.getXMax(), :);
                scale = obj.getDims(true) ./ [obj.width, obj.height];
                patch.cdata = imresize(patch.cdata, scale([2, 1]), 'bilinear');
            elseif obj.x_stride < 1
                patch = im(obj.y_min : obj.getYMax(), obj.x_min : obj.getXMax(), :);
                scale = [obj.y_stride, obj.x_stride];
                patch.cdata = imresize(patch.cdata, scale, 'bilinear');
            else
                patch = im(obj.y_min : obj.y_stride : obj.getYMax(), ...
                    obj.x_min : obj.x_stride : obj.getXMax(), :);
            end
            
            if ~was_img
                im = im.cdata;
            end
        end
    end
end
