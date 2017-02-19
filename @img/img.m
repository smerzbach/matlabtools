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
        channel_names; % e.g. 'RGB' or numeric values for multispectral
    end
    
    properties(Access = public)
        interpolate = true;
        extrapolate = false;
        interpolation_method;
        extrapolation_method;
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
                    obj = varargin{1}.copy();
                else
                    error('cannot construct img object from class %s', class(varargin{1}));
                end
                varargin = varargin(2 : end);
            end
            
            % parse name-value pairs
            for ii = 1 : 2 : numel(varargin)
                if ~ischar(varargin{ii})
                    error('Inputs should be name-value pairs of parameters.');
                end
                switch lower(varargin{ii})
                    case {'channel_names', 'channels', 'chans', 'wls', 'wavelengths'}
                        assert(numel(varargin{ii + 1}) == size(obj.cdata, 3), ...
                            ['Number of elements in the channel names argument ', ...
                            'must match the number of channels.']);
                        obj.channel_names = varargin{ii + 1};
                    otherwise
                        error('Unknown parameter %s.', varargin{ii});
                end
            end
            
            if isempty(obj.channel_names)
                % try to guess channel format
                switch size(obj.cdata, 3)
                    case 1
                        % luminosity
                        obj.channel_names = 'L';
                    case 3
                        % RGB is default for 3 channels
                        obj.channel_names = 'RGB';
                    otherwise
                        % assign uniform sampling between 400 and 700 nm
                        obj.channel_names = linspace(400, 700, size(obj.cdata, 3));
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
                error('sizes don''t match and arrays / imgs cannot be repeated.');
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
                error('sizes don''t match and arrays / imgs cannot be repeated.');
            end
        end
        
        function obj_out = uminus(obj)
            obj_out = obj.copy();
            obj_out.cdata = -img_net.cdata;
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
                error('multiplication can only be performed with scalars or matrices.');
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
            end
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
            comp = [];
            dim = [];
            if numel(varargin) > 1
                dim = varargin{2};
            end
            
            if numel(varargin)
                comp = varargin{1};
            end
            
            if ~isa(obj, 'img')
                % swap if min(1, im) was called
                tmp = obj;
                obj = comp;
                comp = tmp;
            end
            
            obj_out = obj.copy();
            
            if isempty(dim)
                obj_out.cdata(:) = min(obj.cdata(:), comp(:));
            else
                obj_out.cdata(:) = min(obj.cdata, comp, dim);
            end
        end
        
        function obj_out = max(obj, varargin)
            % compute minimum element (optionally along specified dimension)
            comp = [];
            dim = [];
            if numel(varargin) > 1
                dim = varargin{2};
            end
            
            if numel(varargin)
                comp = varargin{1};
            end
            
            if ~isa(obj, 'img')
                % swap if min(1, im) was called
                tmp = obj;
                obj = comp;
                comp = tmp;
            end
            
            obj_out = obj.copy();
            
            if isempty(dim)
                obj_out.cdata(:) = max(obj.cdata(:), comp(:));
            else
                obj_out.cdata(:) = max(obj.cdata, comp, dim);
            end
        end
        
%% ACCESSORS
        function varargout = subsref(obj, S)
            % subscripted indexing via '()' or '{}', as well as '.' for
            % property / method access.
            
            subs = S.subs;
            s = obj.size4();
            n = numel(subs);
            
            if numel(obj) > 1
                error('arrays of img objects are not supported. please use cell arrays!');
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
                            varargout{1} = obj.height();
                        otherwise
                            % pass all other properties to builtin

                            % take property attributes into account!
                            prop = obj.findprop(S(1).subs);
                            if isempty(prop)
                                error('no such property ''%s''.', S(1).subs);
                            end
                            if strcmp(prop.GetAccess, 'public')
                                varargout{1} = builtin('subsref', obj, S);
                            else
                                error('reading ''%s'' is not allowed.', S(1).subs);
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
                    error('no support for this operation.');
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
                        error('subscript indices must be whole numbers. forgot to enable interpolation?');
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
                        error('subscript indices out of range. forgot to enable extrapolation?');
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
                        varargout{1} = obj.get(subs{[2, 1, 3, 4]}, true);
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
                                error('arrays of img objects are not supported. please use cell arrays!');
                            end
                        elseif strcmp(S.type, '{}')
                            error('2');
                        else
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
                                        error('setting ''%s'' is not allowed. use ''obj(:, :, :, :) = array;'' instead.', S(1).subs);
                                    else
                                        error('setting ''%s'' is not allowed.', S(1).subs);
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
                        error('operation not supported.');
                    end
                case '{}'
                    error('operation not supported.');
            end
        end
        
        function n = numArgumentsFromSubscript(obj, indices, indexingContext)
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
        
        function s = size(obj, varargin)
            s = size(obj.cdata, varargin{:});
        end
        
        function tf = is_monochrome(obj)
            % check if image has only one channel
            tf = false;
            if obj.num_channels == 1
                tf = true;
            end
        end
        
        function tf = is_rgb(obj)
            % check if image is in RGB format
            tf = false;
            if obj.num_channels ~= 3
                return;
            end
            
            if ischar(obj.channel_names) && strcmpi(obj.channel_names, 'rgb') ...
                    || iscell(obj.channel_names) && all(cellfun(@strcmpi, ...
                    obj.channel_names, {'r', 'g', 'b'}))
                tf = true;
            end
        end
        
        function tf = is_XYZ(obj)
            % check if image is in CIE XYZ format
            tf = false;
            if obj.num_channels ~= 3
                return;
            end
            
            if ischar(obj.channel_names) && strcmpi(obj.channel_names, 'XYZ') ...
                    || iscell(obj.channel_names) && all(cellfun(@strcmpi, ...
                    obj.channel_names, {'x', 'y', 'z'}))
                tf = true;
            end
        end
        
        function tf = is_spectral(obj)
            % check if image is multispectral
            tf = false;
            if isnumeric(obj.channel_names)
                tf = true;
            end
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
                % convert multispectral image with the CIE standard
                % observer curves
                [cie_xyz, cie_wls] = tb.ciexyz();
                mat_xyz = interp1(cie_wls, cie_xyz, obj.channel_names, 'linear', 0);
                
                obj_out = mat_xyz * obj;
            else
                error('Conversion from channel format %s to XYZ is not possible.', ...
                    obj.channels_to_str());
            end
            obj_out.channel_names = 'XYZ';
        end
        
        function obj_out = to_rgb(obj)
            % convert image to RGB color space
            if obj.is_rgb()
                % nothing to do
                obj_out = obj.copy();
            elseif obj.is_XYZ()
                % might fail for some data types
                obj_out = obj.copy();
                obj_out.cdata = xyz2rgb(obj.cdata);
            elseif obj.is_spectral()
                obj_XYZ = obj.to_XYZ();
                obj_out = obj_XYZ.copy();
                obj_out.cdata = xyz2rgb(obj_XYZ.cdata);
            else
                error('Conversion from channel format %s to RGB is not possible.', ...
                    obj.channels_to_str());
            end
            obj_out.channel_names = 'RGB';
        end
        
        function channel_str = channels_to_str(obj)
            % get string representation of the channel names
            channel_str = tb.to_str(obj.channel_names);
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
        function write(obj, file_path, varargin)
            
        end
        
        function read(obj, file_path, varargin)
            
        end
        
        function obj_out = colon(obj, num_frames, other_obj)
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
        
        function changed(obj, src, evnt)
            % change listener callback updates all assigned viewer objects
            if ~isempty(obj.viewers)
                for vi = 1 : numel(obj.viewers)
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
                        error('unsupported character indexing: %s', subs{ii});
                    end
                end
            end
            
            [ys, xs, cs, fs] = deal(subs{:});
        end
        
        function values = get(obj, xs, ys, channels, frames, cart_prod)
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
            elseif obj.num_channels == 1 && obj.num_frames > 1 || ...
                        any(cellfun(@numel, obj.interpolant.GridVectors) ~= s([1, 2, 4]))
                if isempty(obj.interpolant) || numel(obj.interpolant.GridVectors) ~= 3 || ...
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
                if isempty(obj.interpolant) || numel(obj.interpolant.GridVector) ~= 4 || ...
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
