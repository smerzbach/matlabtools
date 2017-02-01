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
% Helper class for that enables customized subscripting behavior.
classdef ind_obj < handle
    properties
        value;
        factor = 1;
        
        first;
        mid;
        last;
    end
    
    methods
        function obj = ind_obj(input)
            if ~exist('input', 'var')
                input = [];
            end
            
            obj.value = input;
        end
        
        function values = colon(varargin)
            values = tb.ind_obj();
            values.first = varargin{1};
            values.mid = 1;
            values.last = varargin{2};
            if nargin == 3
                values.mid = varargin{2};
                values.last = varargin{3};
            end
        end
        
        function value = double(obj)
            value = obj.value;
        end
        
        function value = minus(a, b)
            value = tb.ind_obj(double(a) - double(b));
        end
        
        function value = plus(a, b)
            value = tb.ind_obj(double(a) + double(b));
        end
        
        function value = times(a, b)
            value = a;
            value.factor = b;
        end
        
        function value = rdivide(a, b)
            value = a;
            value.factor = 1 ./ b;
        end
        
        function value = mrdivide(a, b)
            value = a;
            value.factor = 1 / b;
        end
        
        function indices = to_inds(obj, max)
            if double(obj.last) < 0
                first = double(obj.first); %#ok<PROPLC>
                factor_first = 1;
                if isa(obj.first, 'tb.ind_obj')
                    factor_first = obj.first.factor;
                end
                mid = double(obj.mid); %#ok<PROPLC>
                last = double(obj.last); %#ok<PROPLC>
                factor_last = 1;
                if isa(obj.last, 'tb.ind_obj')
                    factor_last = obj.last.factor;
                end
                if first < 0 %#ok<PROPLC>
                    first = max + first + 1; %#ok<PROPLC>
                end
                last = max + last + 1; %#ok<PROPLC>
                indices = factor_first * first : mid : factor_last * last; %#ok<PROPLC>
            else
                indices = double(obj.first) : double(obj.mid) : double(obj.last);
            end
        end
    end
end
