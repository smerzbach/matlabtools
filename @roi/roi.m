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
        c_min = 1;
        x_max = 0; % set to 0: use image width, smaller 0: x_max pixel from right boundary
        y_max = 0; % set to 0: use image height, smaller 0: y_max pixel from bottom boundary
        c_max = 0; % set to 0: use all channels, smaller 0: c_max from last channel
        % stride < 0: interpreted like a stride but rescaled using imresize
        % 0 < stride < 1: direct downscaling factor
        % stride > 1: integer valued, direct subsampling
        x_stride = 1;
        y_stride = 1;
        c_stride = 1;
        
        channels = [];
        
        height = 0;
        width = 0;
        num_channels = 0;
    end
    
    methods
        function obj = roi(mat, varargin)
            % construct roi object from 2 x 2 or 2 x 3 matrix, where
            % mat = [x_min, x_stride, x_max; y_min, y_stride, y_max]
            % optionally, an image array or object can be provided that is used
            % to determine the image height and width
            
            obj.x_min = mat(1, 1);
            obj.y_min = mat(2, 1);
            obj.x_max = mat(1, end);
            obj.y_max = mat(2, end);
            if size(mat, 2) == 3
                % stride specified
                obj.x_stride = mat(1, 2);
                obj.y_stride = mat(2, 2);
            end
            if size(mat, 1) == 3
                obj.c_min = mat(3, 1);
                obj.c_max = mat(3, end);
                if size(mat, 2) == 3
                    % stride specified
                    obj.c_stride = mat(3, 2);
                end
            end
            
            [varargin, im] = arg(varargin, 'im', [], false);
            [varargin, obj.channels] = arg(varargin, 'channels', [], false);
            arg(varargin);
            
            if ~isempty(im)
                obj.setImage(im);
            end
        end
        
        function setImage(obj, im)
            [obj.height, obj.width, obj.num_channels] = size(im);
        end
        
        function setImageSize(obj, width, height, num_channels)
            if ~isscalar(width)
                warning('roi:invalid_input', 'use setImage to update image dimensions from a single object');
                obj.setImage(width);
                return;
            end
            obj.height = height;
            obj.width = width;
            obj.num_channels = num_channels;
        end
        
        function mat = getMat(obj, im)
            % return a matrix representation of the currently selected ROI
            
            % get image dimensions
            if exist('im', 'var') && ~isempty(im)
                [h, w, nc] = size(im);
            else
                h = obj.height;
                w = obj.width;
            end
            
            mat = [obj.x_min, obj.x_stride, obj.x_max;
                obj.y_min, obj.y_stride, obj.y_max;
                obj.c_min, obj.c_stride, obj.c_max];
            
            if mat(1, 3) <= 0
                mat(1, 3) = w + mat(1, 3);
            end
            
            if mat(2, 3) <= 0
                mat(2, 3) = h + mat(2, 3);
            end
            
            if mat(3, 3) <= 0
                mat(3, 3) = nc + mat(3, 3);
            end
        end
        
        function setXMin(obj, x_min)
            obj.x_min = x_min;
        end
        
        function setYMin(obj, y_min)
            obj.y_min = y_min;
        end
        
        function setXMax(obj, x_max)
            obj.x_max = x_max;
            obj.x_min = min(obj.x_min, obj.getXMax());
        end
        
        function setYMax(obj, y_max)
            obj.y_max = y_max;
            obj.y_min = min(obj.y_min, obj.getYMax());
        end
        
        function setCMax(obj, c_max)
            obj.c_max = c_max;
            obj.c_min = min(obj.c_min, obj.getCMax());
        end
        
        function x_min = getXMin(obj)
            x_min = obj.x_min;
        end
        
        function y_min = getYMin(obj)
            y_min = obj.y_min;
        end
        
        function c_min = getCMin(obj)
            c_min = obj.c_min;
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
        
        function c_max = getCMax(obj, im)
            % return the largest channel index inside of the ROI
            
            % get number of channels
            if exist('im', 'var') && ~isempty(im)
                [~, ~, nc] = size(im);
            else
                nc = obj.num_channels;
            end
            
            if obj.c_max > 0
                c_max = obj.c_max;
            else
                % roi.c_max = 0: num_channels, roi.c_max < 0: c_max = num_channels - c_max
                if nc == 0
                    error('roi:missing_input', ...
                        ['please provide an image so that the actual pixel ', ...
                        'coordinates can be estimated for the selected ROI']);
                end
                c_max = nc + obj.c_max;
            end
        end
        
        function [width, height, num_channels] = getDims(obj, with_strides) %#ok<INUSD>
            with_strides = default('with_strides', true);
            if with_strides
                if obj.x_stride < 0
                    width = numel(obj.x_min : -obj.x_stride : obj.getXMax());
                elseif obj.x_stride < 1
                    width = round(numel(obj.x_min : obj.getXMax()) * obj.x_stride);
                else
                    width = numel(obj.x_min : obj.x_stride : obj.getXMax());
                end
                
                if obj.y_stride < 0
                    height = numel(obj.y_min : -obj.y_stride : obj.getYMax());
                elseif obj.y_stride < 1
                    height = round(numel(obj.y_min : obj.getYMax()) * obj.y_stride);
                else
                    height = numel(obj.y_min : obj.y_stride : obj.getYMax());
                end
                
                if obj.c_stride < 0
                    num_channels = numel(obj.c_min : -obj.c_stride : obj.getCMax());
                elseif obj.c_stride < 1
                    num_channels = round(numel(obj.c_min : obj.getCMax()) * obj.c_stride);
                else
                    num_channels = numel(obj.c_min : obj.c_stride : obj.getCMax());
                end
            else
                width = obj.x_max - obj.x_min + 1;
                height = obj.y_max - obj.y_min + 1;
                num_channels = obj.c_max - obj.c_min + 1;
            end
        end
        
        function patch = apply(obj, im)
            was_img = isa(im, 'img');
            
            if ~was_img
                im = img(im);
            end
            
            if ~isempty(obj.channels)
                if isnumeric(obj.channels)
                    woi = ismember(im.wls, obj.channels);
                    woi = find(woi);
                else
                    woi = ismember(im.channel_names, obj.channels);
                    woi = find(woi);
                end
            else
                woi = obj.c_min : obj.c_stride : obj.getCMax();
            end
            
            assert(im.height == obj.height && im.width == obj.width && ...
                im.num_channels == obj.num_channels, ...
                'image dimensions must match the ROI dimensions!');
            
            if obj.x_stride < 0 || obj.y_stride < 0
                patch = im(obj.y_min : obj.getYMax(), obj.x_min : obj.getXMax(), ...
                    woi);
                scale = min(1 ./ abs([obj.x_stride, obj.y_stride]));
                patch.cdata = imresize(patch.cdata, scale, 'bilinear');
            elseif obj.x_stride < 1 || obj.y_stride < 1 ...
                    || mod(obj.x_stride, 1) ~= 0 || mod(obj.y_stride, 1) ~= 0
                patch = im(obj.y_min : obj.getYMax(), obj.x_min : obj.getXMax(), ...
                    woi);
                scale = tb.size2(patch, 1 : 2) .* [obj.y_stride, obj.x_stride];
                patch.cdata = imresize(patch.cdata, scale, 'bilinear');
            else
                patch = im(obj.y_min : obj.y_stride : obj.getYMax(), ...
                    obj.x_min : obj.x_stride : obj.getXMax(), ...
                    woi);
            end
            
            if ~was_img
                patch = patch.cdata;
            end
        end
        
        function im = applyChannels(obj, im)
            was_img = isa(im, 'img');
            
            if ~was_img
                im = img(im);
            end
            
            if ~isempty(obj.channels)
                if isnumeric(obj.channels)
                    woi = ismember(im.wls, obj.channels);
                    woi = find(woi);
                else
                    woi = ismember(im.channel_names, obj.channels);
                    woi = find(woi);
                end
            else
                woi = obj.c_min : obj.c_stride : obj.getCMax();
            end
            im = im(:, :, woi);
            
            if ~was_img
                im = im.cdata;
            end
        end
    end
end
