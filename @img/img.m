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
%
% TODO: how to handle multispectral images that additionally store channels
% with non-numerical names?
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
        interpolant; % interpolant object (for now griddedInterpolant) that can be used for interpolating pixel values
        interpolant_dirty; % indicates the interpolant requires an update when pixel values have changed
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
                if isnumeric(varargin{1}) || islogical(varargin{1})
                    obj.cdata = varargin{1};
                elseif isa(varargin{1}, 'img')
                    % using handle.copy() here prevents subclassing img -_-
                    obj = varargin{1}.copy_without_cdata();
                    obj.cdata = varargin{1}.cdata;
                    obj.viewers = varargin{1}.viewers;
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
            
            % reorder RGB channels if they exist (e.g. BGR -> RGB)
            if all(cellfun(@ischar, obj.channel_names)) && ...
                    isempty(setdiff({'R', 'G', 'B'}, obj.channel_names))
                inds_from = cellfun(@(c) find(strcmp(obj.channel_names, c), 1), {'R', 'G', 'B'});
                inds_from = [inds_from, setdiff(1 : obj.num_channels, inds_from)];
                obj.cdata = obj.cdata(:, :, inds_from, :);
                obj.set_channel_names(obj.channel_names(inds_from));
            end
            
            % mark interpolant as dirty so it is initialized when first used
            obj.interpolant_dirty = true;
            
            obj.listener_handle = addlistener(obj, 'cdata', 'PostSet', @obj.changed);
        end
        
        function obj_copy = copy_without_cdata(obj)
            % create an "empty" copy of an existing image, containing all
            % the same meta data, including channel names
            mc = metaclass(obj);
            props = {mc.PropertyList.Name}';
            props = setdiff(props, {'cdata'; 'channel_names'; 'viewers'});
            s = obj.size4();
            s([1, 2, 4]) = 0;
            obj_copy = img(zeros(s, class(obj.cdata)), ...
                'wls', obj.channel_names);
            for ii = 1 : numel(props)
                obj_copy.(props{ii}) = obj.(props{ii});
            end
            obj_copy.interpolant_dirty = true;
        end
    end
    
    %% customized (un)serialization methods
    methods
        function s = saveobj(obj)
            % given an img object, this function stores all the data in a
            % struct for storage in a mat file; volatile data like viewer
            % handles are not stored
            mc = metaclass(obj);
            props = {mc.PropertyList.Name}';
            props = setdiff(props, {'viewers'});
            s = struct();
            for ii = 1 : numel(props)
                s.(props{ii}) = obj.(props{ii});
            end
        end
    end
    
    methods(Static)
        function obj = loadobj(s)
            % given a struct stored in a mat file, this function
            % reconstructs an img object
            obj = img(s.cdata, 'wls', s.channel_names);
            fns = fieldnames(s);
            fns = setdiff(fns, {'cdata', 'channel_names'});
            for ii = 1 : numel(fns)
                obj.(fns{ii}) = s.(fns{ii});
            end
        end
    end
    
    methods(Access = public)
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
            non_empty_inds = ~cellfun(@isempty, varargin);
            img_inds = cellfun(@(x) isa(x, 'img'), varargin(non_empty_inds));
            arr_inds = cellfun(@(x) isnumeric(x), varargin(non_empty_inds));
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
            obj_out = imgs{1}.copy_without_cdata();
            all_wls = cfun(@(im) im.get_wavelengths(), imgs);
            
            if ~all(cellfun(@(wls) all(all_wls{1} == wls), all_wls))
                error('img:fixme', 'deal with channels!');
            end
            obj_out.assign(cdata_cat);
        end
        
        function obj_out = repmat(obj, varargin)
            % repeat image along specified dimensions
            if isempty(varargin)
                error('img:invalid_input', ...
                    'please specify repetitions along the different dimensions as input arguments.');
            end
            if numel(varargin) == 1
                reps = varargin{2};
            else
                reps = [varargin{:}];
            end
            nd = numel(reps);
            dims_missing = 4 - nd;
            reps = [reps(:)', ones(1, dims_missing)];
            
            obj_out = obj.copy_without_cdata();
            obj_out.assign(repmat(obj.cdata, reps));
            
            % duplicate channel names accordingly
            channels_out = repmat(obj.channel_names(:)', 1, reps(3));
            obj_out.set_channel_names(channels_out);
        end
        
%% OPERATIONS
        function obj_out = abs(obj)
            % absolute value of the image
            obj_out = obj.copy_without_cdata();
            obj_out.assign(abs(obj.cdata));
            obj_out.interpolant_dirty = true;
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
            
            obj_out = a.copy_without_cdata();
            obj_out.assign(a.cdata + b.cdata);
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
            
            obj_out = a.copy_without_cdata();
            obj_out.assign(a.cdata - b.cdata);
        end
        
        function obj_out = uminus(obj)
            % unary minus
            obj_out = obj.copy_without_cdata();
            obj_out.assign(-obj.cdata);
            obj_out.interpolant_dirty = true;
        end
        
        function obj_out = times(obj, input)
            % element-wise multiplication by scalar (element-wise), vector
            % (pixel-wise) or matrix (channel-wise)
            if isa(input, 'img')
                tmp = obj;
                obj = input;
                input = tmp;
            end
            
            if ~isa(input, 'img')
                input = img(input);
            end
            
            s = obj.size4();
            sin = input.size4();
            obj_out = obj.copy_without_cdata();
            
            if isscalar(input)
                input = repmat(input, 1, 1, s(3));
            elseif isvector(input)
                assert(numel(input) == s(3), ...
                    'input length must match the number of channels in the image!');
                input = reshape(input, 1, 1, s(3));
            elseif ismatrix(input)
                assert(all(sin(1 : 2) == s(1 : 2)), ...
                    'image x and y dimensions must match for channel-wise multiplication with a matrix!');
                input = repmat(input, 1, 1, s(3));
            else
                assert(all(sin(1 : 3) == s(1 : 3)), ...
                    'all image dimensions must match for element-wise multiplication by a 3D array!');
            end
            
            obj_out.assign(bsxfun(@times, obj.cdata, input.cdata));
            obj_out.interpolant_dirty = true;
        end
        
        function obj_out = mtimes(obj, input)
            % pixel-wise matrix (or scalar) multiplication
            if isa(input, 'img')
                % make right multiplication work as well -> swap arguments
                % & transpose matrix, so that left multiplication is
                % equivalent
                tmp = obj;
                obj = input;
                input = tmp;
            end
            if ~ismatrix(input)
                error('img:mtimes_input', ...
                    'multiplication can only be performed with scalars or matrices.');
            end
            
            s = obj.size4();
            obj_out = obj.copy_without_cdata();
            
            if isscalar(input)
                obj_out.assign(input .* obj.cdata);
            elseif ismatrix(input)
                [nrows, ncols] = size(input);
                assert(ncols == s(3), ...
                    'number of matrix colums should match the number of channels in the image!');
                obj_out.assign(zeros(s(1), s(2), nrows, s(4), 'like', obj.cdata));
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
            obj_out.interpolant_dirty = true;
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
            obj_out = obj.copy_without_cdata();
            
            if isscalar(input)
                input = repmat(input, 1, 1, s(3));
            elseif isvector(input)
                assert(numel(input) == s(3), ...
                    'input length must match the number of channels in the image!');
                input = reshape(input, 1, 1, s(3));
            elseif ismatrix(input)
                assert(all(sin(1 : 2) == s(1 : 2)), ...
                    'image x and y dimensions must match for channel-wise division by a matrix!');
                input = repmat(input, 1, 1, s(3));
            else
                assert(all(sin(1 : 3) == s(1 : 3)), ...
                    'all image dimensions must match for division by a 3D array!');
            end
            
            obj_out.assign(bsxfun(@rdivide, obj.cdata, input));
            obj_out.interpolant_dirty = true;
        end
        
        function obj_out = power(obj, exponent)
            % element-wise power
            obj_out = obj.copy_without_cdata();
            obj_out.assign(obj.cdata .^ exponent);
            obj_out.interpolant_dirty = true;
        end
        
        function obj_out = transpose(obj)
            % short hand notation for transposing a multi-channel image
            obj_out = obj.copy_without_cdata();
            obj_out.assign(permute(obj.cdata, [2, 1, 3, 4]));
            obj_out.interpolant_dirty = true;
        end
        
        function obj_out = ctranspose(obj)
            % short hand notation for transposing a multi-channel image
            obj_out = obj.copy_without_cdata();
            obj_out.assign(conj(permute(obj.cdata, [2, 1, 3, 4])));
            obj_out.interpolant_dirty = true;
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
                
                if numel(varargin) && isa(varargin{1}, 'img')
                    % swap formerly numeric input and img object
                    tmp = obj;
                    obj = varargin{1};
                    varargin{1} = tmp;
                end
            end
            
            if numel(varargin) == 0
                % minimum element
                obj_out = min(obj.cdata(:));
            elseif numel(varargin) == 1
                % element-wise minimum of two images
                if ~isa(varargin{1}, 'img')
                    varargin{1} = img(varargin{1});
                end
                
                obj_out = obj.copy_without_cdata();
                tmp = min(obj.cdata(:), varargin{1}.cdata(:));
                obj_out.assign(reshape(tmp, obj.size));
                obj_out.interpolant_dirty = true;
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
                
                if numel(varargin) && isa(varargin{1}, 'img')
                    % swap formerly numeric input and img object
                    tmp = obj;
                    obj = varargin{1};
                    varargin{1} = tmp;
                end
            end
            
            if numel(varargin) == 0
                % maximum element
                obj_out = max(obj.cdata(:));
            elseif numel(varargin) == 1
                % element-wise maximum of two images
                if ~isa(varargin{1}, 'img')
                    varargin{1} = img(varargin{1});
                end
                
                obj_out = obj.copy_without_cdata();
                tmp = max(obj.cdata(:), varargin{1}.cdata(:));
                obj_out.assign(reshape(tmp, obj.size()));
                obj_out.interpolant_dirty = true;
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
            
            obj_out = obj.copy_without_cdata();
            obj_out.cdata = tb.clamp(obj.cdata, lower, upper);
            obj_out.interpolant_dirty = true;
        end
        
%% ACCESSORS & MODIFIERS
        function obj = assign(obj, assignment, varargin)
            % assign values with arbitrary indexing, useful for anonymous
            % functions
            if numel(varargin) > 0
                obj.cdata(varargin{:}) = assignment;
            else
                obj.cdata = []; % wtf? why is this necessary?
                obj.cdata = assignment;
            end
            obj.interpolant_dirty = true;
        end
        
        function obj = set_zero(obj)
            % fill entire image with zeros
            obj.cdata(:) = 0;
            obj.interpolant_dirty = true;
        end
        
        function set_one(obj)
            % fill entire image with ones
            obj.cdata(:) = 1;
            obj.interpolant_dirty = true;
        end
        
        function varargout = subsref(obj, S)
            % indexing via '()' or '{}', as well as '.' for property /
            % method access.
            
            if builtin('numel', obj) > 1
                error('img:object_arrays', ...
                    'arrays of img objects are not supported. please use cell arrays!');
            end
            varargout = cell(1, nargout);
            if strcmp(S(1).type, '.')
                % access to properties or methods
                
                % we can use this to introduce shorthand aliases for some
                % of the class's properties
                if numel(S) == 1
                    subs = S.subs;
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
                    [varargout{:}] = builtin('subsref', obj, S);
                end
            elseif strcmp(S(1).type, '()') && numel(S) == 1
                % subscripting with () works on the underlying cdata array
                % but returns another img object
                subs = S.subs;
                n = numel(subs);
                s = obj.size4();
                
                cell_subs = cellfun(@iscell, subs);
                if any(cell_subs)
                    % any of the input the subscripts is a cell array ->
                    % don't form cartesian product between these subscripts
                    % (see linref)
                    subs(cell_subs) = cfun(@(s) s{1}, subs(cell_subs));
                    [varargout{:}] = obj.linref(subs{:});
                    return;
                end
                
                s(n) = prod(s(n : end));
                s(n + 1 : end) = [];
                iscolon = cellfun(@(sub) strcmp(sub, ':'), subs);
                subs(iscolon) = cfun(@(sub, siz) 1 : siz, subs(iscolon), num2cell(s(iscolon)));
                S.subs = subs;
                
                % check if there are subscripts with decimal digits,
                % which means the samples need to be interpolated
                interpolate = any(cellfun(@(x) nnz(rem(x, 1)), subs)); %#ok<PROPLC>
                if interpolate && ~obj.interpolate %#ok<PROPLC>
                    error('img:no_interpolation', ...
                        'subscript indices must be whole numbers. forgot to enable interpolation?');
                end

                % check if there are subscripts outside of the image
                % dimensions, which requires extrapolation
                extrapolate = any(cellfun(@(sub, siz) any(sub < 1) || any(sub > siz), ...
                    subs(:), col(num2cell(s(1 : n))))); %#ok<PROPLC>
                if extrapolate && ~obj.extrapolate %#ok<PROPLC>
                    error('img:no_extrapolation', ...
                        'subscript indices out of range. forgot to enable extrapolation?');
                end

                % direct indexing or interpolation / extrapolation
                if interpolate || extrapolate %#ok<PROPLC>
                    % interpolation does not return an image object because
                    % the output is not necessarily on an ordered grid
                    varargout{1} = obj.interp(subs{:});
                else
                    varargout{1} = obj.copy_without_cdata();
                    varargout{1}.assign(builtin('subsref', obj.cdata, S));
                    channels_out = obj.get_channels_from_subs(S);
                    if numel(channels_out) > varargout{1}.num_channels
                        % when using linear indexing, we might have merged
                        % some of the channels
                        channels_out = {horzcat(channels_out{:})};
                    end
                    varargout{1}.set_channel_names(channels_out);
                end
            elseif numel(S) >= 2 && strcmp(S(1).type, '()') && strcmp(S(2).type, '.')
                % obj(123 : 124, 1 : 10, :).cdata and the like
                tmp_obj = subsref(obj, S(1));
                [varargout{:}] = subsref(tmp_obj, S(2 : end));
            else
                error('img:invalid_subscripting', 'invalid subscripting: %s', [S.type]);
            end
        end
        
        function obj = subsasgn(obj, S, assignment)
            % Subscripted assignment via '()', '{}' or '.' for property
            % access.
            
            if strcmp(S(1).type, '.')
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
                        case 'interpolant_dirty'
                            obj.interpolant_dirty = assignment;
                        case {'channel_names', 'channels', 'wavelengths', 'wls'}
                            obj.set_channel_names(assignment);
                        case 'name'
                            obj.set_name(assignment);
                        otherwise
                            % pass through all other properties to
                            % builtin

                            % take property attributes into account!
                            prop = obj.findprop(S(1).subs);
                            if strcmp(prop.SetAccess, 'public') || strcmp(S(1).subs, 'cdata')
                                obj = builtin('subsasgn', obj, S, assignment);
                            else
                                % customize some error messages
                                error('img:property_private', ...
                                    'setting ''%s'' is not allowed.', S(1).subs);
                            end
                    end
                else
                    % hand over nested calls to the builtin function
                    obj = builtin('subsasgn', obj, S, assignment);
                end
            elseif strcmp(S(1).type, '()')
                % standard subscripted assignment with braces
                if numel(S) == 1
                    % assignments with braces to object go to cdata member
                    cell_subs = cellfun(@iscell, S.subs);

                    if any(cell_subs)
                        % any of the input the subscripts is a cell
                        % array -> don't form cartesian product between
                        % these subscripts (see linref)
                        subs = S.subs;
                        subs(cell_subs) = cfun(@(s) s{1}, subs(cell_subs));
                        obj.linasgn(subs{:}, assignment);
                    else
                        obj.assign(builtin('subsasgn', obj.cdata, S, assignment));
                    end
                    obj.changed();
                else
                    error('img:no_chained_subscripting', ...
                        'operation not supported.');
                end
            elseif strcmp(S(1).type, '{}')
                error('img:no_assignment_to_curly_braces', ...
                    'operation not supported.');
            end
        end
        
        function ind = end(obj, k, n)
            % enable usage of 'end' for indexing
            assert(n <= 4, 'please specify between 1 and 4 subscripts.');
            s = obj.size4();
            ind = s(k);
        end
        
        function output = linref(obj, ys, xs, cs, fs) %#ok<INUSD>
            % refer to image elements with linear indexing in the x and y
            % coordinates, i.e. instead of forming the cartesian product of
            % all x and y coordinates, this function computes linear
            % indices in the xy-dimension. indexing color channels and
            % frames acts as usual, i.e. we form the cartesian product
            % between those and the xy-dimensions.
            %
            % this method is also called when an img object is indexed
            % with cell arrays
            s = obj.size4();
            cs = default('cs', 1 : s(3));
            fs = default('fs', 1 : s(4));
            
            nxy = numel(xs);
            nc = numel(cs);
            nf = numel(fs);
            
            ys = ys(:);
            xs = xs(:);
            cs = reshape(cs, 1, 1, [], 1);
            fs = reshape(fs, 1, 1, 1, []);
            
            assert(numel(xs) == numel(ys), 'img:invalid_input', ...
                'xs and ys must have the same size.');
            
            xs = repmat(xs, 1, 1, nc, nf);
            ys = repmat(ys, 1, 1, nc, nf);
            cs = repmat(cs, nxy, 1, 1, nf);
            fs = repmat(fs, nxy, 1, nc, 1);
            
            linds = sub2ind(s, ys, xs, cs, fs);
            output = obj.cdata(linds);
        end
        
        function output = linasgn(obj, varargin)
            % assign image elements with linear indexing in the x and y
            % coordinates, i.e. instead of forming the cartesian product of
            % all x and y coordinates, this function computes linear
            % indices in the xy-dimension. color channels and frames act as
            % usual, i.e. we form the cartesian product over those
            % dimensions. the last argument is the assignment, which has to
            % match the number of specified coordinates (times the number
            % of channel indices times the number of frame indices). if it
            % only matches the number of xy coordinates, it is replicated
            % along the channel and frame dimensions.
            %
            % this method is also called when an img object is indexed
            % with cell arrays
            assignment = varargin{end};
            varargin(end) = [];
            
            s = obj.size4();
            ys = varargin{1};
            xs = varargin{2};
            varargin(1 : 2) = [];
            if numel(varargin)
                cs = varargin{1};
                varargin(1) = [];
            else
                cs = 1 : s(3);
            end
            if numel(varargin)
                fs = varargin{1};
                varargin(1) = [];
            else
                fs = 1 : s(4);
            end
            assert(isempty(varargin), 'img:invalid_input', ...
                ['input must be between two and four coordinate ', ...
                'arrays and one assignment.']);
            
            nxy = numel(xs);
            nc = numel(cs);
            nf = numel(fs);
            
            ys = ys(:);
            xs = xs(:);
            cs = reshape(cs, 1, 1, [], 1);
            fs = reshape(fs, 1, 1, 1, []);
            
            assert(numel(xs) == numel(ys), 'img:invalid_input', ...
                'xs and ys must have the same size.');
            
            xs = repmat(xs, 1, 1, nc, nf);
            ys = repmat(ys, 1, 1, nc, nf);
            cs = repmat(cs, nxy, 1, 1, nf);
            fs = repmat(fs, nxy, 1, nc, 1);
            
            assignment = assignment(:);
            if numel(assignment) == nxy
                assignment = repmat(assignment, 1, 1, nc, nf);
            elseif numel(assignment) == nxy * nc
                assignment = repmat(assignment, 1, 1, 1, nf);
            elseif numel(assignment) ~= nxy * nc * nf
                error('img:invalid_input', ['number of elements in assignment ', ...
                    'must match the coordinates']);
            end
            
            linds = sub2ind(s, ys, xs, cs, fs);
            
            obj.interpolant_dirty = true;
            
            if nargout
                output = obj.copy_without_cdata();
            else
                output = obj;
            end
            output.cdata(linds) = assignment;
        end
        
        function values = interp(obj, ys, xs, channels, frames) %#ok<INUSD>
            % multi-linear interpolation on the image data
            obj.update_interpolant();
            
            channels = default('channels', 1);
            frames = default('frames', 1);
            
            [ys, xs, channels, frames] = obj.char_subs_to_linds(ys, xs, channels, frames);
            
            if obj.num_channels == 1 && obj.num_frames == 1
                values = obj.interpolant(ys, xs);
            elseif obj.num_channels > 1 && obj.num_frames == 1
                nx = numel(xs);
                nc = numel(channels);
                if nx ~= nc
                    ys = repmat(ys, 1, numel(channels));
                    xs = repmat(xs, 1, numel(channels));
                    channels = repmat(channels(:)', nx, 1);
                end
                values = obj.interpolant(ys(:), xs(:), channels(:));
                values = reshape(values, [], nc);
            elseif obj.num_channels == 1 && obj.num_frames > 1
                values = obj.interpolant({ys, xs, frames});
            else
                values = obj.interpolant({ys, xs, channels, frames});
            end
        end
        
        function update_interpolant(obj)
            % initialize gridded interpolant on the image data
            s = obj.size4();
            if ~isempty(obj.interpolant)
                si = cellfun(@numel, obj.interpolant.GridVectors);
            end
            
            if isempty(obj.interpolant) || any(si ~= s(s > 1)) || obj.interpolant_dirty
                % interpolation object
                % we can only interpolate along those dimensions which have
                % the necessary number of samples
                sampling = afun(@(s) 1 : s, s(s > 1));
                values = squeeze(obj.cdata);
                obj.interpolant = griddedInterpolant(sampling, values, ...
                    'linear', 'none');
            end
            
            % mark interpolant as clean
            obj.interpolant_dirty = false;
        end
        
        function obj_out = reshape(obj, varargin)
            % reshape the underlying array
            obj_out = obj.copy_without_cdata();
            obj_out.assign(reshape(obj.cdata, varargin{:}));
            
            if size(obj_out.cdata, 3) ~= numel(obj_out.channel_names)
                % check if channel names still match
                warning('img:invalid_reshape', ...
                    'channel names no longer match for reshaped image!');
            end
            
            obj_out.interpolant_dirty = true;
        end
        
        function obj_out = resize(obj, varargin)
            % resample image
            obj_out = obj.copy_without_cdata();
            obj_out.cdata = imresize(obj.cdata, varargin{:});
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
            % size function returns dimensions of underlying array
            varargout = cell(1, max(1, nargout));
            [varargout{:}] = size(obj.cdata, varargin{:});
        end
        
        function s = size4(obj)
            % get size vector but fill up missing dimensions to always
            % return 4 element array
            s = obj.size();
            s = [s, ones(1, 4 - numel(s))];
        end
        
        function str = class(obj)
            % return class of object as string, this is overloaded to allow
            % displaying strings like 'img (uint8)' in the workspace list;
            % use class(obj.cdata) to get the underlying numeric data type
            str = ['img (', class(obj.cdata), ')'];
        end
        
        function tf = isfloat(obj)
            % check if underlying array is of floating point type
            tf = isfloat(obj.cdata);
        end
        
        function tf = isinteger(obj)
            % check if underlying array is of integer type
            tf = isinteger(obj.cdata);
        end
        
        function tf = islogical(obj)
            % check if underlying array is of logical type
            tf = islogical(obj.cdata);
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
            
            if all(cellfun(@ischar, obj.channel_names)) ...
                    && (isempty(setdiff({'r', 'g', 'b'}, ...
                    cfun(@lower, obj.channel_names))) ...
                    || isempty(setdiff(cfun(@lower, obj.channel_names), ...
                    {'r', 'g', 'b'})))
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
            if ~(obj.is_monochrome() || obj.is_rgb() || obj.is_XYZ()) ...
                || any(cellfun(@isnumeric, obj.channel_names)) ...
                || any(~isnan(str2double(obj.channel_names)))
                
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
        
        function set_channel_names(obj, channel_names)
            % update the image's channel names
            if ~iscell(channel_names) && ischar(channel_names) && ...
                    numel(channel_names) == obj.num_channels
                channel_names = num2cell(channel_names);
            end
            assert(iscell(channel_names), ...
                'Channel names must be provided as a cell array.');
            assert(numel(channel_names) == size(obj.cdata, 3), ...
                ['Number of elements in the channel names ', ...
                'must match the number of image channels.']);
            obj.channel_names = channel_names(:)';
        end
        
        function channel_names = get_channel_names_raw(obj)
            % get string or numeric representation of image channel names
            channel_names = obj.channel_names;
        end
        
        function channel_str = channels_to_str(obj)
            % get string representation of the channel names
            channel_str = tb.to_str(obj.channel_names);
        end
        
        function str = string(obj)
            % get string representation of image object
            props = properties(obj);
            
            inds = cellfun(@(p) any(strcmp({'interpolate', 'extrapolate', ...
                'interpolation_method', 'extrapolation_method', 'user', 'name'}, p)), props);
            props = props(~inds);
            if ~isempty(obj.name)
                props = [{'name'}; props];
            end
            
            vals = cfun(@(p) {obj.(p)}, props);
            pvs = [props(:)'; vals(:)'];
            prop_list = struct(pvs{:}); %#ok<NASGU>
            str = evalc('disp(prop_list)');
            
            if ~isempty(obj.user)
                indent = regexp(str, '(\s+)cdata: ', 'tokens');
                str = sprintf('%s%s user:\n', str(1 : end - 1), indent{1}{1});
                str = [str, evalc('disp(obj.user)')];
            end
            
            str = strrep(str, sprintf('\n    '), sprintf('\n')); %#ok<SPRINTFN>
            str = str(5 : end);
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
        
        function obj = to_double(obj)
            % convert to img obj of double array
            obj.assign(single(obj.cdata));
        end
        
        function obj = to_single(obj)
            % convert to img obj of single array
            obj.assign(single(obj.cdata));
        end
        
        function obj = to_int64(obj)
            % convert to img obj of int64 array
            obj.assign(int64(obj.cdata));
        end
        
        function obj = to_int32(obj)
            % convert to img obj of int32 array
            obj.assign(int32(obj.cdata));
        end
        
        function obj = to_int16(obj)
            % convert to img obj of int16 array
            obj.assign(int16(obj.cdata));
        end
        
        function obj = to_int8(obj)
            % convert to img obj of int8 array
            obj.assign(int8(obj.cdata));
        end
        
        function obj = to_uint64(obj)
            % convert to img obj of uint64 array
            obj.assign(uint64(obj.cdata));
        end
        
        function obj = to_uint32(obj)
            % convert to img obj of uint32 array
            obj.assign(uint32(obj.cdata));
        end
        
        function obj = to_uint16(obj)
            % convert to img obj of uint16 array
            obj.assign(uint16(obj.cdata));
        end
        
        function obj = to_uint8(obj)
            % convert to img obj of uint8 array
            obj.assign(uint8(obj.cdata));
        end
        
        function obj = to_logical(obj)
            % convert to img obj of logical array
            obj.assign(logical(obj.cdata));
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
        
        function obj_out = to_XYZ(obj)
            % convert image to CIE XYZ color space
            if obj.is_rgb()
                % might fail for some data types
                obj_out = obj.copy_without_cdata();
                obj_out.assign(rgb2xyz(obj.cdata));
                obj_out.interpolant_dirty = true;
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
                % nothing to do except grabbing the right channels
                obj_out = obj.copy_without_cdata();
                [~, inds] = ismember({'R', 'G', 'B'}, obj.channel_names);
                obj_out.assign(obj.cdata(:, :, inds, :));
                obj_out.interpolant_dirty = true;
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
                    if all(size(conversion_mat) == [obj.num_channels, 3])
                        conversion_mat = conversion_mat';
                    end
                    assert(all(size(conversion_mat) == [3, obj.num_channels]), ...
                        'RGB conversion matrix must be of shape [3, %d]', obj.num_channels);
                    mat_rgb = conversion_mat;
                    
                    % normalize to keep the same energy
                    % TODO: this is not the right way to do this. instead
                    % one should account for the differential wavelengths
                    mat_rgb = mat_rgb ./ max(sum(mat_rgb, 2));
                else
                    mat_rgb = obj.rgb_conversion_mat();
                    
                    if isempty(mat_rgb)
                        tmp = cellfun(@(x) ['''', num2str(x), ''', '], obj.channel_names, ...
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
            obj_out.set_channel_names('RGB');
        end
        
        function [mat_rgb, wls] = rgb_conversion_mat(obj)
            % return the default RGB conversion matrix with a wavelength
            % sampling matching the one of the image
            [cie_rgb, cie_wls] = tb.cie_rgb_1931();
            if obj.is_spectral
                wls = obj.get_wavelengths();
                mat_rgb = interp1(cie_wls, cie_rgb', wls, ...
                    'linear', 0)';
            else
                mat_rgb = cie_rgb;
                wls = cie_wls;
            end

            % normalize to keep the same energy
            % TODO: this is not the right way to do this. instead
            % one should account for the differential wavelengths
            mat_rgb = mat_rgb ./ max(sum(mat_rgb, 2));
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
                    imc.interpolant_dirty = true;
                    imchannels{wi} = imc;
                end
            elseif obj.is_rgb()
                for wi = 1 : 3
                    imc = img(zeros(obj.height, obj.width, 3, 'like', obj.cdata), 'wls', 'RGB');
                    imc.cdata(:, :, wi) = obj.cdata(:, :, wi);
                    if clamp_negative
                        imc = imc.clamp(0, inf);
                    end
                    imc.interpolant_dirty = true;
                    imchannels{wi} = imc;
                end
            else
                error('img:colorize_channels', 'image must be either multispectral or RGB.');
            end
        end
        
        function obj = storeUserData(obj, input)
            % store user data in the .user field
            if isstruct(input)
                if ~isstruct(obj.user)
                    obj.user = struct();
                end
                fns = fieldnames(input);
                for fi = 1 : numel(fns)
                    obj.user.(fns{fi}) = input.(fns{fi});
                end
            else
                obj.user = input;
            end
        end
        
        function [counts, bins] = hist(obj, varargin)
            % compute histograms (optionally channel-wise)
            [varargin, channel_wise] = arg(varargin, 'channel_wise', false);
            [varargin, bins] = arg(varargin, 'bins', 100); %#ok<ASGLU>
            
            if isinteger(obj.cdata)
                pixels = single(obj.cdata);
            else
                pixels = obj.cdata;
            end
            
            if channel_wise
                channels = squeeze(mat2cell(pixels, obj.height, obj.width, ones(obj.num_channels, 1)));
                if isscalar(bins)
                    % compute unified bins for all channels
                    pixels_finite = pixels(isfinite(pixels));
                    mi = min(pixels_finite(:));
                    ma = max(pixels_finite(:));
                    if mi == ma
                        ma = mi + 10 * eps(single(mi));
                    end
                    bins = linspace(mi, ma, bins + 1);
                end
                if numel(bins) == 2 && bins(1) == bins(2)
                    bins(2) = bins(1) + eps(bins(1));
                end
                [counts, bins] = cfun(@(channel) histcounts(channel(:), bins), channels);
                bins = bins{1};
            else
                [counts, bins] = histcounts(pixels(:), bins);
                % return output in the same format as if channel wise
                counts = {counts};
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
        
        function remove_all_viewers(obj)
            obj.viewers = [];
        end
        
%% IO
        function imwrite(obj, varargin)
            % save image to disk
            % for now, this simply calls the builtin imwrite with whatever
            % arguments that were provided
            imwrite(obj.cdata, varargin{:});
        end
    end
        
    methods(Access = protected)
        function changed(obj, src, evnt) %#ok<INUSD>
            % change listener callback, updates all assigned viewer objects
            if isempty(obj.cdata)
                return;
            end
            if ~isempty(obj.viewers)
                for vi = 1 : numel(obj.viewers)
                    obj.viewers(vi).change_image();
                    obj.viewers(vi).paint();
                end
            end
        end
        
        function channels = get_channels_from_subs(obj, S)
            % when indexing, we need to access the channels accordingly
            subs = S(1).subs;
            n = numel(subs);
            % convert potentially linear indices to subscripts
            s = obj.size4();
            subs2 = cell(1, 4 - n + 1);
            [subs2{:}] = ind2sub(s(min(3, n) : end), subs{min(3, n)});
            % get all the accessed channels' indices
            cs = unique(subs2{max(1, end - 1)});
            channels = obj.get_channel_names();
            channels = channels(cs);
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
    end
    
    methods
        % function that explicitly need to be defined inside a methods
        % block withouth any access attributes
        
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
    end
end
