% *************************************************************************
% * Copyright 2019 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2019-01-06
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
% 2D highpass filter for removing image gradients.
% The filtering kernel for cutting off high frequencies of the fourier
% transform of each channel is parameterized over its standard deviation
% sigma and an additional slope parameter gamma as follows:
%
% k = (1 - (exp(-x^2 / sigma^2) * exp(-y^2 / sigma^2))) ^ gamma
function [imfiltered, kernel] = imhighpass(im, varargin)
    [varargin, sigma] = arg(varargin, 'sigma', [0.001, 0.001], false);
    if ~isempty(sigma) && numel(sigma) == 1
        sigma = repmat(sigma, 1, 2);
    end
    [varargin, sigma_x] = arg(varargin, 'sigma_x', sigma(1), false);
    [varargin, sigma_y] = arg(varargin, 'sigma_y', sigma(2), false);
    [varargin, gamma] = arg(varargin, 'gamma', 5, false);
    arg(varargin);
    
    was_img = isa(im, 'img');
    if ~was_img
        im = img(im);
    end
    
    % set up filter kernel
    [h, w, ~] = size(im);
    ys = linspace(0, h / w, h) - round(h / 2) / w;
    xs = linspace(0, 1, w) - 0.5;
    kernel = bsxfun(@times, exp(-col(ys) .^ 2 / sigma_y .^ 2), exp(-row(xs) .^ 2 / sigma_x .^ 2));
    kernel = (1 - kernel) .^ gamma;
    kernel = fftshift(kernel);
    
    % exclude image mean from filtering
    kernel(1, 1) = 1;
    
    imfiltered = im.copy_without_cdata();
    
    % apply filter channel-wise on fourier transform.
    tmp = cat2(3, cfun(@(map) real(ifft2(kernel .* fft2(map))), ...
        mat2cell2(im.cdata, [], [], 1)));
    imfiltered.assign(tmp);
    
    kernel = fftshift(kernel);
    
    if ~was_img
        imfiltered = imfiltered.cdata;
    end
end
