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
% Image class.
classdef img < handle & matlab.mixin.Copyable
    properties(GetAccess = public, SetAccess = protected, SetObservable, AbortSet)
        cdata; % stores the actual pixel values as a 2D, 3D or 4D array
    end
    
    properties(GetAccess = public, SetAccess = protected)
        % e.g. 'RGB' or numeric values for multispectral images, can also
        % store arbitrary cell arrays of strings
        channel_names;
        
        name = '';
    end
    
    properties(Access = public)
        interpolate = true;
        extrapolate = false;
        interpolation_method;
        extrapolation_method;
        
        user; % user data
    end
    
    properties(Access = protected)
        interpolant;
        viewers; % set of viewer objects that update as soon as the image changes
        listener_handle;
    end
    
    methods(Access = public)
%% CONSTRUCTOR & CONCATENATION
        function obj = img(varargin)
            % Constructs an image object from a numeric array, dimensions
            % should be H x W x C x F, where H is height, W is width, C is
            % the number of channels and optionally F the number of frames.
            if nargin
                if isnumeric(varargin{1})
                    obj.cdata = varargin{1};
                elseif isa(varargin{1}, 'img')
                    % using handle.copy() here prevents subclassing img -_-
                    % obj = varargin{1}.copy();
                    other = varargin{1};
                    obj.cdata = other.cdata;
                    obj.channel_names = other.channel_names;
                    obj.name = other.name;
                    obj.user = other.user;
                    obj.interpolant = other.interpolant;
                    obj.viewers = other.viewers;
                    obj.listener_handle = other.listener_handle;
                else
                    error('img:construction_failed', ...
                        'cannot construct img object from class %s', class(varargin{1}));
                end
                varargin = varargin(2 : end);
            end
            
            % parse name-value pairs
            for ii = 1 : 2 : numel(varargin)
                if ~ischar(varargin{ii})
                    error('img:name_value_pairs', ...
                        'Inputs should be name-value pairs of parameters.');
                end
                switch lower(varargin{ii})
                    case {'channel_names', 'channels', 'chans', 'wls', 'wavelengths'}
                        channel_names = varargin{ii + 1};
                        if ischar(channel_names) || isnumeric(channel_names)
                            channel_names = num2cell(channel_names);
                        end
                        if ~iscell(channel_names)
                            error('img:channel_format', ...
                                'channel names must be provided as cell array');
                        end
                        assert(numel(channel_names) == size(obj.cdata, 3), ...
                            ['Number of elements in the channel names argument ', ...
                            'must match the number of channels.']);
                        obj.set_channel_names(channel_names);
                        if obj.is_spectral()
                            obj.set_channel_names(num2cell(obj.get_wavelengths()));
                        end
                    otherwise
                        error('img:unknown_param', 'Unknown parameter %s.', varargin{ii});
                end
            end
            
            if isempty(obj.channel_names)
                % try to guess channel format
                switch size(obj.cdata, 3)
                    case 1
                        % luminosity
                        obj.channel_names = {'L'};
                    case 3
                        % RGB is default for 3 channels
                        obj.channel_names = {'R', 'G', 'B'};
                    otherwise
                        % assign uniform sampling between 400 and 700 nm
                        obj.channel_names = num2cell(linspace(400, 700, size(obj.cdata, 3)));
                end
            end
            
            obj.listener_handle = addlistener(obj, 'cdata', 'PostSet', @obj.changed);
        end
        
        function obj_out = clone(obj)
            % a simple alias for copy()
            obj_out = obj.copy();
        end
        
        function obj_out = horzcat(varargin)
            % horizontal concatenation [i1, i2, i3, ...] of img objects and
            % / or numeric arrays
            obj_out = cat(2, varargin{:});
        end
        
        function obj_out = vertcat(varargin)
            % vertical concatenation [i1; i2; i3; ...] of img objects and
            % / or numeric arrays
            obj_out = cat(1, varargin{:});
        end
        
        function obj_out = cat(dim, varargin)
            % concatenation along arbitrary dimension (e.g. for stacking
            % channels or frames) of img objects and / or numeric arrays
            
            % treat img objects and numeric arrays separately
            img_inds = cellfun(@(x) isa(x, 'img'), varargin);
            arr_inds = cellfun(@(x) isnumeric(x), varargin);
            if ~all(img_inds | arr_inds)
                error('img:cat_input_mismatch', ...
                    'only img objects and numeric arrays can be concatenated.');
            end
            imgs = varargin(img_inds);
            arrays = varargin(arr_inds);
            
            % ensure all image sizes except dim match
            h = imgs{1}.height();
            w = imgs{1}.width();
            nc = imgs{1}.num_channels();
            nf = imgs{1}.num_frames();
            sizesi = cellfun(@(x) x.size4(), imgs, 'UniformOutput', false);
            sizesi = vertcat(sizesi{:});
            
            if dim ~= 1
                assert(all(sizesi(:, 1) == h), 'images must have the same height!');
            end
            if dim ~= 2
                assert(all(sizesi(:, 2) == w), 'images must have the same width!');
            end
            if dim ~= 3
                assert(all(sizesi(:, 3) == nc), 'images must have the same number of channels!');
            end
            if dim ~= 4
                assert(all(sizesi(:, 4) == nf), 'images must have the same number of frames!');
            end
            
            % check array sizes: they should either exactly match the image
            % sizes (except dim), or should be divisors of the image sizes
            arrays2 = {};
            if ~isempty(arrays)
                sizesa = cellfun(@(x) [size(x), ones(1, 4 - ndims(x))], arrays, 'UniformOutput', false);
                sizesa = vertcat(sizesa{:});

                factors = bsxfun(@rdivide, sizesi(1, :), sizesa);
                factors(:, dim) = 1;
                assert(all(rem(factors(:), 1) == 0), ['size of array(s) must match '...
                    'the image or be repeatable to match the image size, got '...
                    'scaling factors: %f, %f, %f, %f\n'], factors(~all(rem(factors, 1) == 0, 2), :)');

                % repeat the arrays, if necessary
                arrays2 = cellfun(@(x, r) repmat(x, r), arrays(:), ...
                    mat2cell(factors, ones(size(factors, 1), 1), 4), 'UniformOutput', false);
            end
            
            % now collect all inputs as numeric arrays in the correct order
            all_arrays = cell(1, numel(varargin));
            all_arrays(img_inds) = cellfun(@(x) x.cdata, imgs, 'UniformOutput', false);
            all_arrays(arr_inds) = arrays2;
            
            % matlab downcasts everything to the smallest data type (i.e. a
            % single uint8 array in the inputs would result in a uint8 img
            % as output), so we manually cast everything to the highest
            % precision type among the inputs
            [type, differ] = tb.get_common_type(all_arrays{:});
            if differ
                all_arrays = cellfun(@(x) cast(x, type), all_arrays, 'UniformOutput', false);
            end
            
            % perform the actual concatenation
            cdata_cat = cat(dim, all_arrays{:});
            obj_out = imgs{1}.copy();
            obj_out.cdata = cdata_cat;
        end
        
        function obj_out = repmat(obj, varargin)
            % repeat image along specified dimensions
            obj_out = obj.copy();
            obj_out.cdata = repmat(obj_out.cdata, varargin{:});
        end
        
%% OPERATIONS
        function obj = assign(obj, assignment, varargin)
            % assign values with arbitrary indexing, useful for anonymous
            % functions
            obj.cdata(varargin{:}) = assignment;
        end
        
        function obj = set_zero(obj)
            obj.cdata(:) = 0;
        end
        
        function set_one(obj)
            obj.cdata(:) = 1;
        end
        
        function obj_out = abs(obj)
            % absolute value of the image
            obj_out = obj.copy();
            obj_out.cdata = abs(obj_out.cdata);
        end
        
        function obj_out = plus(a, b)
            % addition of an img with another img or numeric array. if
            % sizes don't match, it is attempted to repeat the respectively
            % smaller array or img to the bigger size.
            assert(all(cellfun(@(x) isa(x, 'img') || isnumeric(x), {a, b})), ...
                'only img objects and numeric arrays can be added.');
            
            if isnumeric(a)
                % 123 + img1
                a = img(a);
            elseif isnumeric(b)
                % img1 + 123
                b = img(b);
            end
            s1 = a.size4();
            s2 = b.size4();
            
            if all(s1 >= s2)
                factors = s1 ./ s2;
                assert(all(rem(factors, 1) == 0), ['size of img objects must match '...
                    'or be repeatable, got scaling factors: %f, %f, %f, %f\n'], ...
                    factors(~all(rem(factors, 1) == 0, 2), :)');
                obj_out = b.copy();
                obj_out.cdata = repmat(obj_out.cdata, factors);
                
                obj_out.cdata = obj_out.cdata + a.cdata;
            elseif all(s2 >= s1)
                factors = s2 ./ s1;
                assert(all(rem(factors, 1) == 0), ['size of img objects must match '...
                    'or be repeatable, got scaling factors: %f, %f, %f, %f\n'], ...
                    factors(~all(rem(factors, 1) == 0, 2), :)');
                obj_out = a.copy();
                obj_out.cdata = repmat(obj_out.cdata, factors);
                
                obj_out.cdata = obj_out.cdata + b.cdata;
            else
                error('img:plus_dimension_mismatch', ...
                    'sizes don''t match and arrays / imgs cannot be repeated.');
            end
        end
        
        function obj_out = minus(a, b)
            % subtraction of an img from another img or numeric array. if
            % sizes don't match, it is attempted to repeat the respectively
            % smaller array or img to the bigger size.
            assert(all(cellfun(@(x) isa(x, 'img') || isnumeric(x), {a, b})), ...
                'only img objects and numeric arrays can be added.');
            
            if isnumeric(a)
                % 123 - img1
                a = img(a);
            elseif isnumeric(b)
                % img1 - 123
                b = img(b);
            end
            s1 = a.size4();
            s2 = b.size4();
            
            if all(s1 >= s2)
                factors = s1 ./ s2;
                assert(all(rem(factors, 1) == 0), ['size of img objects must match '...
                    'or be repeatable, got scaling factors: %f, %f, %f, %f\n'], ...
                    factors(~all(rem(factors, 1) == 0, 2), :)');
                obj_out = b.copy();
                obj_out.cdata = repmat(obj_out.cdata, factors);
                
                obj_out.cdata = a.cdata - obj_out.cdata;
            elseif all(s2 >= s1)
                factors = s2 ./ s1;
                assert(all(rem(factors, 1) == 0), ['size of img objects must match '...
                    'or be repeatable, got scaling factors: %f, %f, %f, %f\n'], ...
                    factors(~all(rem(factors, 1) == 0, 2), :)');
                obj_out = a.copy();
                obj_out.cdata = repmat(obj_out.cdata, factors);
                
                obj_out.cdata = obj_out.cdata - b.cdata;
            else
                error('img:minus_dimension_mismatch', ...
                    'sizes don''t match and arrays / imgs cannot be repeated.');
            end
        end
        
        function obj_out = uminus(obj)
            obj_out = obj.copy();
            obj_out.cdata = -img_net.cdata;
        end
        
        function obj_out = times(obj, input)
            % element-wise multiplication by scalar (element-wise), vector
            % (pixel-wise) or matrix (channel-wise)
            if isa(input, 'img')
                tmp = obj;
                obj = input;
                input = tmp';
            end
            
            if ~isa(input, 'img')
                input = img(input);
            end
            
            s = obj.size4();
            sin = input.size4();
            obj_out = obj.copy();
            
            if isscalar(input)
                input = repmat(input, 1, 1, s(3));
            elseif isvector(input)
                assert(numel(input) == s(3), ...
                    'input length must match the number of channels in the image!');
                input = reshape(input, 1, 1, s(3));
            elseif ismatrix(input)
                assert(all(sin(1 : 2) == s(1 : 2)), ...
                    'image x and y dimensions must match for element-wise multiplication with a matrix!');
                input = repmat(input, 1, 1, s(3));
            else
                assert(all(sin(1 : 3) == s(1 : 3)), ...
                    'all image dimensions must match for element-wise multiplication by a 3D array!');
            end
            
            obj_out.cdata = bsxfun(@times, obj_out.cdata, input.cdata);
        end
        
        function obj_out = mtimes(obj, input)
            % pixel-wise matrix (or scalar) multiplication
            if isa(input, 'img')
                % make right multiplication work as well -> swap arguments
                % & transpose matrix, so that left multiplication is
                % equivalent
                tmp = obj;
                obj = input;
                input = tmp';
            end
            if ~ismatrix(input)
                error('img:mtimes_input', ...
                    'multiplication can only be performed with scalars or matrices.');
            end
            
            s = obj.size4();
            obj_out = obj.copy();
            
            if isscalar(input)
                obj_out.cdata = input .* obj_out.cdata;
            elseif ismatrix(input)
                [nrows, ncols] = size(input);
                assert(ncols == s(3), ...
                    'number of matrix colums should match the number of channels in the image!');
                obj_out.cdata = zeros(s(1), s(2), nrows, s(4), 'like', obj_out.cdata);
                for fi = 1 : s(4)
                    tmp = reshape(obj.cdata(:, :, :, fi), [], s(3));
                    tmp = tmp * input.';
                    obj_out.cdata(:, :, :, fi) = reshape(tmp, s(1), s(2), nrows);
                end
                
                % invalidate channel names after matrix-image
                % multiplication (meaning or even number of channels
                % changes)
                obj_out.channel_names = cellfun(@(x) sprintf('C%d', x), ...
                    num2cell(1 : obj_out.num_channels), 'UniformOutput', false);
            end
        end
        
        function obj_out = rdivide(obj, input)
            % right division by scalar (element-wise), vector (pixel-wise)
            % or matrix (channel-wise)
            if ~isa(obj, 'img') && isa(input, 'img')
                % [1; 2; 3] ./ im_obj does not make sense
                error('img:array_division', 'right array division must be used as: im_obj ./ vector.');
            end
            if isa(input, 'img')
                input = input.cdata;
            end
            
            s = obj.size4();
            sin = zeros(1, 4);
            sin(1 : ndims(input)) = size(input);
            obj_out = obj.copy();
            
            if isscalar(input)
                input = repmat(input, 1, 1, s(3));
            elseif isvector(input)
                assert(numel(input) == s(3), ...
                    'input length must match the number of channels in the image!');
                input = reshape(input, 1, 1, s(3));
            elseif ismatrix(input)
                assert(all(sin(1 : 2) == s(1 : 2)), ...
                    'image x and y dimensions must match for right division by a matrix!');
                input = repmat(input, 1, 1, s(3));
            else
                assert(all(sin(1 : 3) == s(1 : 3)), ...
                    'all image dimensions must match for division by a 3D array!');
            end
            
            obj_out.cdata = bsxfun(@rdivide, obj_out.cdata, input);
        end
        
        function obj_out = power(obj, exponent)
            % element-wise power
            obj_out = obj.copy();
            obj_out.cdata = obj_out.cdata .^ exponent;
        end
        
        function obj_out = transpose(obj)
            obj_out = obj.copy();
            obj_out.cdata = permute(obj_out.cdata, [2, 1, 3, 4]);
        end
        
        function obj_out = ctranspose(obj)
            obj_out = obj.copy();
            obj_out.cdata = conj(permute(obj_out.cdata, [2, 1, 3, 4]));
        end
        
        function m = mean(obj, dim)
            % compute mean along selected, potentially multiple dimensions
            if ~exist('dim', 'var')
                dim = 3;
            end
            
            if ischar(dim) && strcmp(dim, ':')
                dim = 1 : 4;
            end
            dim = sort(dim);
            
            % iterate over potentially multiple dimensions
            m = obj.cdata;
            for ii = 1 : numel(dim)
                m = mean(m, dim(ii));
            end
        end
        
        function m = avg(obj, dim)
            % same as mean
            if ~exist('dim', 'var')
                dim = 3;
            end
            
            m = obj.mean(dim);
        end
        
        function obj_out = min(obj, varargin)
            % compute minimum element (optionally along specified dimension)
            if ~isa(obj, 'img')
                obj = img(obj);
            end
            
            if numel(varargin) == 0
                % minimum element
                obj_out = min(obj.cdata(:));
            elseif numel(varargin) == 1
                % element-wise minimum of two images
                
                if ~isa(varargin{1}, 'img')
                    varargin{1} = img(varargin{1});
                end
                
                if varargin{1}.bigger_than(obj)
                    tmp = obj;
                    obj = varargin{1};
                    varargin{1} = tmp;
                end
                
                obj_out = obj.copy();
                obj_out.cdata(:) = min(obj.cdata(:), varargin{1}.cdata(:));
            elseif numel(varargin) == 2 % (img, [], dim)
                % minimum along specified dimension
                obj_out = tb.min2(obj.cdata, varargin{:});
            else
                error('img:min_arguments', 'unsupported number of inputs.');
            end
        end
        
        function obj_out = max(obj, varargin)
            % compute minimum element (optionally along specified dimension)
            if ~isa(obj, 'img')
                obj = img(obj);
            end
            
            if numel(varargin) == 0
                % maximum element
                obj_out = max(obj.cdata(:));
            elseif numel(varargin) == 1
                % element-wise maximum of two images
                
                if ~isa(varargin{1}, 'img')
                    varargin{1} = img(varargin{1});
                end
                
                if varargin{1}.bigger_than(obj)
                    tmp = obj;
                    obj = varargin{1};
                    varargin{1} = tmp;
                end
                
                obj_out = obj.copy();
                obj_out.cdata(:) = max(obj.cdata(:), varargin{1}.cdata(:));
            elseif numel(varargin) == 2 % (img, [], dim)
                % maximum along specified dimension
                obj_out = tb.max2(obj.cdata, varargin{:});
            else
                error('img:max_arguments', 'unsupported number of inputs.');
            end
        end
        
        function obj_out = clamp(obj, lower, upper)
            % clamp image values to lower and upper bounds
            if ~exist('lower', 'var') || isempty(lower)
                lower = 0;
            end
            
            if ~exist('upper', 'var') || isempty(upper)
                upper = inf;
            end
            
            obj_out = obj.copy();
            obj_out(:, :, :, :) = tb.clamp(obj_out.cdata, lower, upper);
        end
        
%% ACCESSORS
        function varargout = subsref(obj, S)
            % subscripted indexing via '()' or '{}', as well as '.' for
            % property / method access.
            
            subs = S.subs;
            s = obj.size4();
            n = numel(subs);
            
            if builtin('numel', obj) > 1
                error('img:object_arrays', ...
                    'arrays of img objects are not supported. please use cell arrays!');
            end
            if strcmp(S(1).type, '.')
                % access to properties or methods
                if numel(S) == 1
                    switch subs
                        case {'interpolation_method', 'method', 'Method'}
                            obj.update_interpolant();
                            varargout{1} = obj.interpolant.Method;
                        case {'extrapolation_method', 'ExtrapolationMethod'}
                            obj.update_interpolant();
                            varargout{1} = obj.interpolant.ExtrapolationMethod;
                        case {'height', 'h'}
                            varargout{1} = obj.height();
                        case {'width', 'w'}
                            varargout{1} = obj.width();
                        case {'num_channels', 'nc'}
                            varargout{1} = obj.num_channels();
                        case {'num_frames', 'nf'}
                            varargout{1} = obj.num_frames();
                        case {'channel_names', 'channels'}
                            varargout{1} = obj.get_channel_names();
                        case {'wavelengths', 'wls'}
                            varargout{1} = obj.get_wavelengths();
                        case 'name'
                            varargout{1} = obj.get_name();
                        otherwise
                            % pass all other properties to builtin

                            % take property attributes into account!
                            prop = obj.findprop(S(1).subs);
                            if isempty(prop)
                                error('img:missing_property', ...
                                    'no such property ''%s''.', S(1).subs);
                            end
                            if strcmp(prop.GetAccess, 'public')
                                varargout{1} = builtin('subsref', obj, S);
                            else
                                error('img:private_property', ...
                                    'reading ''%s'' is not allowed.', S(1).subs);
                            end
                    end
                else
                    % hand over nested calls to the builtin function
                    [varargout{1 : nargout}] = builtin('subsref', obj, S);
                end
            elseif strcmp(S(1).type, '()') || strcmp(S(1).type, '{}')
                % indexing via brackets will return a new img object,
                % whereas curly braces will return a raw numerical array

                if numel(S) > 1
                    % no chained subscripting like foo(1, 1 : 2)(3)
                    error('img:no_chained_subscripting', ...
                        'no support for this operation.');
                end

                if isa(subs{1}, 'tb.ind_obj')
                    subs{1} = subs{1}.to_inds(s(1));
                end
                
                % we support special indexing operations via logical
                % arrays (called mask from now on) in combination with
                % standard numerical subscripting
                if any(cellfun(@islogical, subs))
                    % if a mask is used, interpolation is disabled
                    interpolate = false; %#ok<PROPLC>
                    extrapolate = false; %#ok<PROPLC>
                else
                    % deal with subscripts that contained the 'end' keyword
                    for ii = 2 : numel(subs)
                        if isa(subs{ii}, 'tb.ind_obj')
                            subs{ii} = subs{ii}.to_inds(s(ii));
                        end
                    end
                    
                    % check if there are subscripts with decimal digits,
                    % which means the samples need to be interpolated
                    interpolate = any(cellfun(@(x) nnz(rem(x, 1)), subs)); %#ok<PROPLC>
                    if interpolate && ~obj.interpolate %#ok<PROPLC>
                        error('img:no_interpolation', ...
                            'subscript indices must be whole numbers. forgot to enable interpolation?');
                    end
                    
                    % check if there are subscripts outside of the image
                    % dimensions, which requires extrapolation
                    extrapolate = false; %#ok<PROPLC>
                    for ii = 1 : numel(subs)
                        if isnumeric(subs{ii})
                            extrapolate = extrapolate | ...
                                any(subs{ii}(:) < 1 | ...
                                subs{ii}(:) > s(ii)); %#ok<PROPLC>
                        end
                    end
                    if extrapolate && ~obj.extrapolate %#ok<PROPLC>
                        error('img:no_extrapolation', ...
                            'subscript indices out of range. forgot to enable extrapolation?');
                    end
                end
                
                if islogical(subs{1})
                    % ii(mask, ..., ...)
                    s1 = size(subs{1});
                    nd1 = numel(s1);

                    % the shape of the mask determines which dimensions are
                    % being indexed, valid are 1 to 4
                    dims_matching = nnz(s1 == s(1 : nd1));
                    % ensure there are no mismatching dimensions in between
                    assert(all(s1 == s(1 : nd1)) || ...
                        find(s1 ~= s(1 : nd1), 1, 'first') > find(s1 == s(1 : nd1), 1, 'last'), ...
                        'd-dimensional logical array must match the first d image dimensions!');
                    dims_missing = 4 - dims_matching - (n - 1);
                    
                    % deal with subscripts that contained the 'end' keyword
                    for ii = 2 : numel(subs)
                        if isa(subs{ii}, 'tb.ind_obj')
                            subs{ii} = subs{ii}.to_inds(s(dims_matching + ii - 1));
                        end
                    end

                    % fill up missing dimensions by full indices
                    subs = [subs, cellfun(@(x) 1 : x, ...
                        num2cell(s(end - dims_missing + 1 : end)), ...
                        'UniformOutput', false)];

                    % we now convert the mask to linear indices over
                    % the corresponding dimensions
                    if dims_matching == 1
                        % mask is vector
                        subs{1} = find(subs{1});
                        [subs{:}] = obj.char_subs_to_linds(subs{:});
                        [subs{:}] = ndgrid(subs{:});
                        linds = sub2ind(s, subs{:});
                        linds = reshape(linds, [], s(2), s(3), s(4));
                    elseif dims_matching == 2
                        % mask is 2D
                        subs{1} = find(subs{1});
                        [~, ~, subs{2}, subs{3}] = obj.char_subs_to_linds([], [], subs{2}, subs{3});
                        [subs{:}] = ndgrid(subs{:});
                        linds = sub2ind([s(1) * s(2), s(3 : 4)], subs{:});
                        linds = reshape(linds, [], 1, s(3), s(4));
                    elseif dims_matching == 3
                        % mask is 3D
                        subs{1} = find(subs{1});
                        [~, ~, ~, subs{2}] = obj.char_subs_to_linds([], [], [], subs{2});
                        [subs{:}] = ndgrid(subs{:});
                        linds = sub2ind([s(1) * s(2) * s(3), s(4)], subs{:});
                        linds = reshape(linds, [], s(4));
                    elseif dims_matching == 4
                        % mask is 4D
                        linds = find(subs{1});
                    end
                    varargout{1} = reshape(obj.cdata(linds), size(linds));
                elseif all(cellfun(@(x) isnumeric(x) || ischar(x), subs))
                    % vanilla subscript indexing, e.g. ii(123, 321, :) etc.
                    
                    % fill up missing dimensions by full indices
                    dims_missing = 4 - n;
                    subs = [subs, cellfun(@(x) 1 : x, ...
                        num2cell(s(end - dims_missing + 1 : end)), ...
                        'UniformOutput', false)];

                    % direct indexing or interpolation / extrapolation
                    if interpolate || extrapolate %#ok<PROPLC>
                        varargout{1} = obj.interp(subs{[2, 1, 3, 4]});
                    else
                        [varargout{1}, channel_names_out] = ...
                            obj.get(subs{[2, 1, 3, 4]}, true);
                    end
                else
                    % ii(123, mask) and everything else
                    % try and pass things on to the builtin subsref
                    
                    % put back the potentially modified subscripts
                    S.subs = subs;
                    curly = false;
                    if strcmp(S.type, '{}')
                        S.type = '()';
                        curly = true;
                    end
                    varargout{1} = builtin('subsref', obj.cdata, S);
                    if curly
                        S.type = '{}';
                    else
                        varargout{1} = img(varargout{1}.cdata);
                    end
                end

                if strcmp(S.type, '()')
                    % () indexing should always return an img object
                    tmp = varargout{1};
                    varargout{1} = obj.copy();
                    varargout{1}.cdata = tmp;
                    varargout{1}.channel_names = channel_names_out;
                end
            end
        end
        
        function obj = subsasgn(obj, S, assignment)
            % Subscripted assignment via '()', '{}' or '.' for property
            % access.
            
            if isa(assignment, 'img')
                if isempty(S)
                    error('1');
                else
                    if numel(S) == 1
                        if strcmp(S.type, '()')
                            if numel(S) > 1% || S.subs{1} ~= 1
                                error('img:object_arrays', ...
                                    'arrays of img objects are not supported. please use cell arrays!');
                            end
                        elseif strcmp(S.type, '{}')
                            error('2');
                        elseif ~strcmp(S.subs, 'cdata')
                            error('3');
                        end
                    else
                        error('4');
                    end
                end
                % FIXME: this is never reached and therefore probably
                % unnecessary
                % TODO: adapt when constructor is complete
                obj.cdata = assignment.cdata;
                obj.changed();
                return;
            end
            
            switch S(1).type
                case '.'
                    if numel(S) == 1
                        % deal with property assignments
                        switch S.subs
                            case {'interpolation_method', 'method', 'Method'}
                                assert(ischar(assignment), ...
                                    'interpolation_method must be string!');
                                obj.update_interpolant();
                                obj.interpolant.Method = assignment;
                            case {'extrapolation_method', 'ExtrapolationMethod'}
                                assert(ischar(assignment), ...
                                    'extrapolation_method must be string!');
                                obj.update_interpolant();
                                obj.interpolant.ExtrapolationMethod = assignment;
                                switch assignment
                                    case 'none'
                                        obj.extrapolate = false;
                                    otherwise
                                        obj.extrapolate = true;
                                end
                            case {'channel_names', 'channels', 'wavelengths', 'wls'}
                                obj.set_channel_names(assignment);
                            case 'name'
                                obj.set_name(assignment);
                            otherwise
                                % pass through all other properties to
                                % builtin
                                
                                % take property attributes into account!
                                prop = obj.findprop(S(1).subs);
                                if strcmp(prop.SetAccess, 'public')
                                    obj = builtin('subsasgn', obj, S, assignment);
                                else
                                    % customize some error messages
                                    if strcmp(S(1).subs, 'cdata')
                                        error('img:cdata_private', ...
                                            ['setting cdata is not allowed. ', ...
                                            'use ''obj(:, :, :, :) = array;'' instead.']);
                                    else
                                        error('img:property_private', ...
                                            'setting ''%s'' is not allowed.', S(1).subs);
                                    end
                                end
                        end
                    else
                        % hand over nested calls to the builtin function
                        obj = builtin('subsasgn', obj, S, assignment);
                    end
                case '()'
                    if numel(S) == 1
                        % assignments with braces to object go to cdata
                        % member
                        inds_new = substruct('.', 'cdata', '()', S.subs(:));
                        obj = subsasgn(obj, inds_new, assignment);
                    else
                        error('img:no_chained_subscripting', ...
                            'operation not supported.');
                    end
                case '{}'
                    error('img:no_assignment_to_curly_braces', ...
                        'operation not supported.');
            end
        end
        
        function n = numArgumentsFromSubscript(obj, indices, indexingContext) %#ok<INUSL>
            % number of return arguments for customized indexing using
            % subsref / subsasgn
            switch indexingContext
                case matlab.mixin.util.IndexingContext.Statement
                    n = 1; % nargout for indexed reference used as statement
                case matlab.mixin.util.IndexingContext.Expression
                    n = 1; % nargout for indexed reference used as function argument
                case matlab.mixin.util.IndexingContext.Assignment
                    n = 1; % nargin for indexed assignment
            end
            
        end
        
        function ind = end(obj, k, n)
            % enable usage of 'end' for indexing
            assert(n <= 4, 'please specify between 1 and 4 subscripts.');
            if n < 4
                % we have too many ambiguous cases
                ind = tb.ind_obj(-1);
            else
                s = obj.size4();
                ind = s(k);
            end
        end
        
        function obj_out = reshape(obj, varargin)
            % reshape the underlying array
            obj_out = obj.copy();
            obj_out.cdata = reshape(obj_out.cdata, varargin{:});
        end
        
        function height = height(obj)
            height = size(obj.cdata, 1);
        end
        
        function width = width(obj)
            width = size(obj.cdata, 2);
        end
        
        function num_channels = num_channels(obj)
            num_channels = size(obj.cdata, 3);
        end
        
        function num_frames = num_frames(obj)
            num_frames = size(obj.cdata, 4);
        end
        
        function varargout = size(obj, varargin)
            varargout = cell(1, nargout);
            [varargout{:}] = size(obj.cdata, varargin{:});
        end
        
        function res = bigger_than(obj, comp)
            % check if a second img object has bigger dimensions
            if ~isa(comp, 'img')
                comp = img(comp);
            end
            
            s1 = obj.size4();
            s2 = comp.size4();
            
            res = 0;
            if all(s1 >= s2)
                res = 1;
            elseif any(s1 > s2) && any(s1 < s2)
                res = -1;
            end
        end
        
        function tf = is_monochrome(obj)
            % check if image has only one channel
            tf = false;
            if obj.num_channels == 1 && ~isnumeric(obj.channel_names{1})
                tf = true;
            end
        end
        
        function tf = is_rgb(obj)
            % check if image is in RGB format
            tf = false;
            if obj.num_channels ~= 3
                return;
            end
            
            if iscell(obj.channel_names) && all(cellfun(@strcmpi, ...
                    obj.channel_names(:), {'r'; 'g'; 'b'}))
                tf = true;
            end
        end
        
        function tf = is_XYZ(obj)
            % check if image is in CIE XYZ format
            tf = false;
            if obj.num_channels ~= 3
                return;
            end
            
            if iscell(obj.channel_names) && all(cellfun(@strcmpi, ...
                    obj.channel_names(:), {'x'; 'y'; 'z'}))
                tf = true;
            end
        end
        
        function tf = is_spectral(obj)
            % check if image is multispectral
            tf = false;
            if ~(obj.is_monochrome() || obj.is_rgb() || obj.is_XYZ())
                tf = true;
            end
        end
        
        function wavelengths = get_wavelengths(obj, input)
            % try to return wavelengths in a numeric array for
            % multispectral images, or an empty array if the image is not
            % spectral
            if ~obj.is_spectral()
                % non-multispectral images should clearly signal that they
                % don't have anything like a wavelength assignment for
                % their channels
                wavelengths = [];
            elseif iscell(obj.channel_names) && ...
                    all(cellfun(@isnumeric, obj.channel_names))
                % the easy case
                wavelengths = cell2mat(obj.channel_names);
            else
                % try to match strings of the form '380.00-389.70nm', as
                % produced e.g. by Mitsuba Renderer, if this fails, try to
                % parse any kind of numbers from the channel name strings
                tokens = regexpi(obj.channel_names, ...
                    '(\d*\.\d{2,})-(\d*\.\d{2,})nm', 'tokens');
                if ~any(cellfun(@isempty, tokens))
                    % if the above format matches, to get a numerical array
                    % the only reasonable thing to do is to take the
                    % central wavelengths
                    
                    bins_start = cellfun(@(x) str2double(x{1}{1}), tokens);
                    bins_end = cellfun(@(x) str2double(x{1}{2}), tokens);
                    wavelengths = mean([bins_start(:), bins_end(:)], 2);
                else
                    % attempt to parse numbers from the channel names
                    wavelengths = cellfun(@str2double, obj.channel_names);
                    if any(isnan(wavelengths))
                        % last resort
                        try
                            wavelengths = cellfun(@(x) sscanf(x, '%f'), ...
                                obj.channel_names);
                            if any(isnan(wavelengths))
                                error('img:channels_non_numeric', ...
                                    'cannot convert channel names to numeric values!');
                            end
                        catch
                            wavelengths = [];
                        end
                    end
                end
            end
            
            % select certain channels only
            if exist('input', 'var')
                wavelengths = wavelengths(input);
            end
        end
        
        function channel_names = get_channel_names(obj)
            % get string representation of image channel names
            channel_names = obj.channel_names;
            num_inds = cellfun(@isnumeric, channel_names);
            channel_names(num_inds) = cellfun(@num2str, channel_names(num_inds), ...
                'UniformOutput', false);
        end
        
        function channel_names = get_channel_names_raw(obj)
            % get string or numeric representation of image channel names
            channel_names = obj.channel_names;
        end
        
        function set_channel_names(obj, channel_names)
            % update the image's channel names
            assert(iscell(channel_names), ...
                'Channel names must be provided as a cell array.');
            assert(numel(channel_names) == size(obj.cdata, 3), ...
                ['Number of elements in the channel names', ...
                'must match the number of image channels.']);
            obj.channel_names = channel_names;
        end
        
        function name = get_name(obj)
            % return name stored in image object
            name = obj.name;
        end
        
        function set_name(obj, name)
            % store name in image object
            obj.name = name;
        end
        
%% CONVERTERS
        function values = double(obj)
            % conversion to numeric array
            values = double(obj.cdata);
        end
        
        function values = single(obj)
            % conversion to numeric array
            values = single(obj.cdata);
        end
        
        function values = int64(obj)
            % conversion to numeric array
            values = int64(obj.cdata);
        end
        
        function values = int32(obj)
            % conversion to numeric array
            values = int32(obj.cdata);
        end
        
        function values = int16(obj)
            % conversion to numeric array
            values = int16(obj.cdata);
        end
        
        function values = int8(obj)
            % conversion to numeric array
            values = int8(obj.cdata);
        end
        
        function values = uint64(obj)
            % conversion to numeric array
            values = uint64(obj.cdata);
        end
        
        function values = uint32(obj)
            % conversion to numeric array
            values = uint32(obj.cdata);
        end
        
        function values = uint16(obj)
            % conversion to numeric array
            values = uint16(obj.cdata);
        end
        
        function values = uint8(obj)
            % conversion to numeric array
            values = uint8(obj.cdata);
        end
        
        function values = logical(obj)
            % conversion to numeric array
            values = logical(obj.cdata);
        end
        
        function obj_out = to_XYZ(obj)
            % convert image to CIE XYZ color space
            if obj.is_rgb()
                % might fail for some data types
                obj_out = obj.copy();
                obj_out.cdata = rgb2xyz(obj.cdata);
            elseif obj.is_XYZ()
                % nothing to do
                obj_out = obj.copy();
            elseif obj.is_spectral()
                % convert multispectral image with the CIE XYZ standard
                % observer curves
                [cie_xyz, cie_wls] = tb.ciexyz();
                mat_xyz = interp1(cie_wls, cie_xyz, obj.get_wavelengths(), ...
                    'linear', 0);
                
                % normalize to keep the same energy
                mat_xyz = mat_xyz ./ max(sum(mat_xyz));
                
                obj_out = mat_xyz * obj;
            else
                error('img:illegal_conversion', ...
                    'Conversion from channel format %s to XYZ is not possible.', ...
                    obj.channels_to_str());
            end
            obj_out.channel_names = {'X', 'Y', 'Z'};
        end
        
        function obj_out = to_rgb(obj, conversion_mat)
            % convert image to RGB color space, optionally with custom
            % conversion matrix
            
            if ~exist('conversion_mat', 'var')
                conversion_mat = [];
            end

            if obj.is_rgb()
                % nothing to do
                obj_out = obj.copy();
            elseif obj.is_XYZ()
                if ~exist('conversion_mat', 'var') || isempty(conversion_mat)
                    mat_rgb = tb.xyz2rgb_mat('cie');
                elseif ischar(conversion_mat)
                    mat_rgb = tb.xyz2rgb_mat(conversion_mat);
                elseif isnumeric(conversion_mat)
                    mat_rgb = conversion_mat;
                end
                obj_out = mat_rgb * obj;
            elseif obj.is_spectral()
                if ~isempty(conversion_mat)
                    assert(all(size(conversion_mat) == [3, obj.num_channels]), ...
                        'RGB conversion matrix must be of shape [3, %d]', obj.num_channels);
                    mat_rgb = conversion_mat;
                else
                    [cie_rgb, cie_wls] = tb.cie_rgb_1931();
                    mat_rgb = interp1(cie_wls, cie_rgb, obj.get_wavelengths(), ...
                        'linear', 0);
                    % normalize to keep the same energy
                    mat_rgb = mat_rgb ./ max(sum(mat_rgb));
                    
                    if isempty(mat_rgb)
                        tmp = cellfun(@(x) ['''', x, ''', '], obj.channel_names, ...
                            'UniformOutput', false);
                        tmp{end} = tmp{end}(1 : end - 2);
                        error('img:unknown_channel_names', ...
                            'the channel names do not allow for automatic conversion to RGB: %s', ...
                            strcat(tmp{:}));
                    end
                end
                obj_out = mat_rgb * obj;
            else
                error('img:illegal_conversion', ...
                    'Conversion from channel format %s to RGB is not possible.', ...
                    obj.channels_to_str());
            end
            obj_out.channel_names = {'R', 'G', 'B'};
        end
        
        function channel_str = channels_to_str(obj)
            % get string representation of the channel names
            channel_str = tb.to_str(obj.channel_names);
        end
        
        function cell_arr = to_cell(obj, dim)
            % return cell array of slices along the specified dimension
            assert(1 <= dim && dim <= 4, 'dim must be one of {1, 2, 3, 4}.');
            s = obj.size4();
            switch dim
                case 1
                    cell_arr = mat2cell(obj.cdata, ones(s(1), 1), s(2), s(3), s(4));
                case 2
                    cell_arr = mat2cell(obj.cdata, s(1), ones(s(2), 1), s(3), s(4));
                case 3
                    cell_arr = mat2cell(obj.cdata, s(1), s(2), ones(s(3), 1), s(4));
                case 4
                    cell_arr = mat2cell(obj.cdata, s(1), s(2), s(3), ones(s(4), 1));
            end
        end
        
        function imchannels = colorize_channels(obj, channel_inds, clamp_negative, conversion_mat)
            % convert each channel's 2D array into an RGB image which is
            % appropriately colorized
            if ~exist('channel_inds', 'var') || isempty(channel_inds)
                channel_inds = 1 : obj.num_channels();
            end
            
            if ~exist('clamp_negative', 'var') || isempty(clamp_negative)
                clamp_negative = false;
            end
            
            if ~exist('conversion_mat', 'var') || isempty(conversion_mat)
                conversion_mat = [];
            end
            
            assert(obj.num_frames() == 1, 'not implemented for multi-frame images!');
            imchannels = cell(1, obj.num_channels);
            if obj.is_spectral()
                wls = obj.get_wavelengths(channel_inds);
                for wi = 1 : numel(wls)
                    imc = img(obj.cdata(:, :, wi), 'wls', wls(wi));
                    imc = imc.to_rgb(conversion_mat);
                    if clamp_negative
                        imc = imc.clamp(0, inf);
                    end
                    imchannels{wi} = imc;
                end
            elseif obj.is_rgb()
                for wi = 1 : 3
                    imc = img(zeros(obj.height, obj.width, 3, 'like', obj.cdata), 'wls', 'RGB');
                    imc.cdata(:, :, wi) = obj.cdata(:, :, wi);
                    if clamp_negative
                        imc = imc.clamp(0, inf);
                    end
                    imchannels{wi} = imc;
                end
            else
                error('img:colorize_channels', 'image must be either multispectral or RGB.');
            end
        end

        
%% CALLBACKS
        function add_viewer(obj, v)
            % add a new viewer object to the set of active viewers, supply
            % an empty array to clear the set
            obj.viewers = union(obj.viewers, v);
        end
        
        function remove_viewer(obj, v)
            % remove a viewer object from the set of active viewers
            obj.viewers = setdiff(obj.viewers, v);
        end
        
%% TODO 
        function imwrite(obj, varargin)
            % save image to disk
            % for now, this simply calls the builtin imwrite with whatever
            % arguments that were provided
            imwrite(obj.cdata, varargin{:});
        end
        
        function read(obj, file_path, varargin) %#ok<INUSD>
            
        end
        
        function obj_out = colon(obj, num_frames, other_obj) %#ok<STOUT,INUSD>
            % interpolates two images or creates multiple frames in between
        end
    end
    
    methods
        function set.viewers(obj, v)
            obj.viewers = v;
        end
    end
    
    methods(Access = protected)
%         function varargout = copyElement(varargin)
%             % customize copy behavior
%         end
        
        function changed(obj, src, evnt) %#ok<INUSD>
            % change listener callback updates all assigned viewer objects
            if ~isempty(obj.viewers)
                for vi = 1 : numel(obj.viewers)
                    obj.viewers(vi).change_image();
                    obj.viewers(vi).paint();
                end
            end
        end
        
        function s = size4(obj)
            % get size vector but fill up missing dimensions to always
            % return 4 element array
            s = obj.size();
            s = [s, ones(1, 4 - numel(s))];
        end
        
        function [ys, xs, cs, fs] = char_subs_to_linds(obj, ys, xs, cs, fs)
            % convert character subscripts for all four dimensions to
            % numeric subscripts; the only supported character is ':'
            s = obj.size4();
            subs = {ys, xs, cs, fs};
            
            for ii = 1 : 4
                if ischar(subs{ii})
                    if strcmp(subs{ii}, ':')
                        subs{ii} = 1 : s(ii);
                    else
                        error('img:illegal_char_subs', ...
                            'unsupported character indexing: %s', subs{ii});
                    end
                end
            end
            
            [ys, xs, cs, fs] = deal(subs{:});
        end
        
        function [values, channel_names] = get(obj, xs, ys, channels, frames, cart_prod)
            % direct access to the image data; if the card_prod agrument is
            % true, then x and y coordinates are treated as pairs instead
            % of forming their cartesian product
            if ~exist('channels', 'var')
                channels = 1 : obj.num_channels();
            end
            
            if ~exist('frames', 'var')
                frames = 1 : obj.num_frames();
            end
            
            if ~exist('cart_prod', 'var')
                cart_prod = true;
            end
            
            % return the selected channel names
            channel_names = obj.channel_names(channels);
            
            if cart_prod
                % conventional indexing
                values = obj.cdata(ys, xs, channels, frames);
            else
                % "loose" pixel pairs, channels and frames as usual
                n = numel(xs);
                assert(n == numel(ys));
                nc = numel(channels);
                nf = numel(frames);
                
                xs = repmat(xs(:), 1, 1, nc, nf);
                ys = repmat(ys(:), 1, 1, nc, nf);
                channels = repmat(reshape(channels, 1, 1, nc), n, 1, 1, nf);
                frames = repmat(reshape(frames, 1, 1, 1, nf), n, 1, nc, 1);
                
                inds = sub2ind(obj.size4(), ys(:), xs(:), channels(:), frames(:));
                values = reshape(obj.cdata(inds), n, 1, nc, nf);
            end
        end
        
        function values = interp(obj, xs, ys, channels, frames)
            % multi-linear interpolation on the image data
            obj.update_interpolant();
            
            [ys, xs, channels, frames] = obj.char_subs_to_linds(ys, xs, channels, frames);
            
            if obj.num_channels == 1 && obj.num_frames == 1
                values = obj.interpolant({ys, xs});
            elseif obj.num_channels > 1 && obj.num_frames == 1
                values = obj.interpolant({ys, xs, channels});
            elseif obj.num_channels == 1 && obj.num_frames > 1
                values = obj.interpolant({ys, xs, frames});
            else
                values = obj.interpolant({ys, xs, channels, frames});
            end
        end
        
        function update_interpolant(obj)
            % initialize gridded interpolant on the image data
            s = obj.size4();
            if obj.num_channels == 1 && obj.num_frames == 1
                if isempty(obj.interpolant) || numel(obj.interpolant.GridVectors) ~= 2 || ...
                        any(cellfun(@numel, obj.interpolant.GridVectors) ~= s(1 : 2))
                    obj.interpolant = griddedInterpolant({...
                        1 : obj.height(), ...
                        1 : obj.width()}, ...
                        obj.cdata, 'linear', 'none');
                else
                    obj.interpolant.GridVectors = {1 : obj.height(), 1 : obj.width()};
                    obj.interpolant.Values = obj.cdata;
                end
            elseif obj.num_channels > 1 && obj.num_frames == 1
                if isempty(obj.interpolant) || numel(obj.interpolant.GridVectors) ~= 3 || ...
                        any(cellfun(@numel, obj.interpolant.GridVectors) ~= s(1 : 3))
                    obj.interpolant = griddedInterpolant({...
                        1 : obj.height(), ...
                        1 : obj.width(), ...
                        1 : obj.num_channels()}, ...
                        obj.cdata, 'linear', 'none');
                else
                    obj.interpolant.GridVectors = {1 : obj.height(), ...
                        1 : obj.width(), 1 : obj.num_channels()};
                    obj.interpolant.Values = obj.cdata;
                end
            elseif obj.num_channels == 1 && obj.num_frames > 1
                if isempty(obj.interpolant) || numel(obj.interpolant.GridVectors) ~= 3 || ...
                        any(cellfun(@numel, obj.interpolant.GridVectors) ~= s([1, 2, 4])) || ...
                        any(cellfun(@numel, obj.interpolant.GridVectors) ~= s([1, 2, 4]))
                    obj.interpolant = griddedInterpolant({...
                        1 : obj.height(), ...
                        1 : obj.width(), ...
                        1 : obj.num_frames()}, ...
                        reshape(obj.cdata, obj.height(), obj.width(), obj.num_frames()));
                else
                    obj.interpolant.GridVectors = {1 : obj.height(), ...
                        1 : obj.width(), 1 : obj.num_frames()};
                    obj.interpolant.cdata = reshape(obj.cdata, obj.height(), ...
                        obj.width(), obj.num_frames());
                end
            else
                if isempty(obj.interpolant) || numel(obj.interpolant.GridVectors) ~= 4 || ...
                        any(cellfun(@numel, obj.interpolant.GridVectors) ~= s)
                    obj.interpolant = griddedInterpolant({...
                        1 : obj.height(), ...
                        1 : obj.width(), ...
                        1 : obj.num_channels(), ...
                        1 : obj.num_frames()}, ...
                        obj.cdata, 'linear', 'none');
                else
                    obj.interpolant.GridVectors = {1 : obj.height, 1 : obj.width(), ...
                        1 : obj.num_channels(), 1 : obj.num_frames};
                    obj.interpolant.Values = obj.cdata;
                end
            end
        end
    end
end
