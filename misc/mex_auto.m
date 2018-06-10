% *************************************************************************
% * Copyright 2017 Sebastian Merzbach
% *
% * authors:
% *  - Sebastian Merzbach <smerzbach@gmail.com>
% *
% * file creation date: 2017-11-23
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
% Automatic MEX compilation by comparing time stamps of source and compiled
% files or if no compiled file exists. Call this function from a matlab
% wrapper function and it will (by default) automatically check if there is
% a compiled MEX file in the same folder as the wrapper with suffix
% "_mex.mexa64" (or the equivalents on Windows / Mac). If it doesn't exist
% or if any of the source files have newer time stamps, it will recompile.
%
% Input is specified as name-value-pairs with the following options:
% - mex_file: desired name of the compiled MEX file, defaults to
%             ['caller_mex', mexext]
% - sources:  cell array of C/C++/Fortran files that need to be compiled,
%             defaults to 'caller_mex.cpp' or 'caller_mex.c'
% - headers:  additional cell array of header files that should be included
%             in the modification time stamps (not passed to mex())
% - openmp:   set to true if you want to compile with OpenMP support
% - cpp11:    set to true (default) to enable the C++11 standard
%
% Any further inputs are directly passed to mex().
%
% As stated above, using mex_auto requires that you maintain an additional
% m-file besides your C/C++ code that calls mex_auto() and the compiled MEX
% function. However, with a simple pattern shown in the examples below, you
% won't have to deal explicitly with input and output arguments. Even
% better, having an accompanying m-file for your source code is a good idea
% in general, as it is so much nicer to do input checks and parsing in
% Matlab than in C/C++! Besides that, you can use the m-file to display
% help texts such as this one, which is not possible with compilable source
% code only.
%
%
% Usage example:
%
% Suppose there is C++ code for a MEX file in example_mex.cpp. Create a
% wrapper function in the same folder with file name example.m according to
% the following pattern:
%
% example.m:
% function varargout = example(varargin)
%     mex_auto(); % this call will trigger automatic compilation of
%     % example_mex.cpp if necessary
%     
%     varargout = cell(1, nargout);
%     % now call the compiled MEX file
%     [varargout{:}] = example_mex(varargin{:});
% end
%
%
% More complex example with multiple source files:
%
% example.m:
% function varargout = example(varargin)
%     mex_auto('sources', {'example_mex.cpp', 'other_source.cpp'}, ...
%         'mex_file', 'example_compiled'); % this call will trigger
%         automatic compilation of example_mex.cpp and other_source.cpp if 
%         necessary
%     
%     varargout = cell(1, nargout);
%     % now call the compiled MEX file
%     [varargout{:}] = example_compiled(varargin{:});
% end
%
function mex_auto(varargin)
    % use the call stack to determine the name of the calling function
    st = dbstack(0, '-completenames');
    [mpath, mname] = fileparts(st(2).file);
    
    % if nothing different is specified, we use the _mex.cpp / _mex.h /
    % _mex.hpp / _mex.mexext naming scheme
    default_mex_file = fullfile(mpath, [mname, '_mex.', mexext]);
    default_source = fullfile(mpath, [mname, '_mex.cpp']);
    default_header = fullfile(mpath, [mname, '_mex.hpp']);
    if ~fexist(default_source)
        default_source = fullfile(mpath, [mname, '_mex.c']);
    end
    if ~fexist(default_header)
        default_header = fullfile(mpath, [mname, '_mex.h']);
    end
    
    % parse potentially different file names for sources, headers and the
    % mex file name
    [varargin, mex_file] = arg(varargin, 'mex_file', {default_mex_file}, false);
    [varargin, sources] = arg(varargin, 'sources', {default_source}, false);
    [varargin, headers] = arg(varargin, 'headers', {default_header}, false);
    [varargin, openmp] = arg(varargin, 'openmp', false);
    [varargin, c11, cpp11, cPP11, CPP11] = arg(varargin, {'c11', 'cpp11', 'c++11', 'C++11'}, false);
    cpp11 = any([c11, cpp11, cPP11, CPP11]);
    
    if openmp
        if isunix || ismac
            varargin = [varargin, ...
                'CFLAGS="\$CFLAGS -fopenmp"', ...
                'CXXFLAGS="\$CXXFLAGS -fopenmp"', ...
                'LDFLAGS="\$LDFLAGS -fopenmp"'];
        else
            % this assumes MSVC, if using MinGW, please use the above flags
            varargin = [varargin, 'COMPFLAGS="/openmp $COMPFLAGS"'];
        end
    end
    
    if cpp11
        if isunix || ismac
            varargin = [varargin, ...
                'CFLAGS="\$CFLAGS -std=c11"', ...
                'CXXFLAGS="\$CXXFLAGS -std=c++11"', ...
                'LDFLAGS="\$LDFLAGS -std=c++11"'];
        else
            warning('mex_auto:no_cpp11_switch', 'no dedicated C++11 switch for MSVC');
        end
    end
    
    if ~iscell(sources)
        sources = {sources};
    end
    if ~iscell(headers)
        headers = {headers};
    end
    
    % deal with user inputs for the file paths which most certainly are not
    % absolute paths
    make_path_absolute = @(file) IF(~fexist(file) && fexist(fullfile(mpath, file)), ...
        fullfile(mpath, file), file);
    sources = cfun(make_path_absolute, sources);
    headers = cfun(make_path_absolute, headers);
    
    % finally remove those source and header files which don't exist
    sources = sources(cellfun(@(file) logical(fexist(file)), sources));
    headers = headers(cellfun(@(file) logical(fexist(file)), headers));
    
    % append mex extension if mex_file doesn't contain it yet
    if ~extension(mex_file, mexext)
        mex_file = [mex_file, mexext];
    end
    
    % path to mex_file not absolute yet?
    if ~strncmp(mpath, mex_file, numel(mpath))
        mex_file = fullfile(mpath, mex_file);
    end
    
    % finally check for existance of all source and header files and die if
    % one is missing
    for ii = 1 : numel(sources)
        assert(logical(fexist(sources{ii})), [mname, ':missing_source'], ...
            'Source file %s could not be found!', sources{ii});
    end
    for ii = 1 : numel(headers)
        assert(logical(fexist(headers{ii})), [mname, ':missing_header'], ...
            'Header file %s could not be found!', headers{ii});
    end
    
    % query file meta data
    mex_struct = dir(mex_file);
    source_structs = cfun(@(fn) dir(fn), sources);
    header_structs = cfun(@(fn) dir(fn), headers);
    
    % check if a compilation is necessary
    mex_missing = isempty(mex_struct);
    source_newer = ~mex_missing && any(cellfun(@(ss) ss.datenum > mex_struct.datenum, source_structs));
    header_newer = ~mex_missing && any(cellfun(@(hs) hs.datenum > mex_struct.datenum, header_structs));
    
    if mex_missing || source_newer || header_newer
        % compile mex file if it cannot be found or if it is outdated
        warning([mname, ':mex_outdated'], ...
            ['the mex file ', mex_file, ' is outdated ', ...
            'or non existant and needs to be compiled.']);
        mex(sources{:}, varargin{:}, ['-I', mpath], ...
            '-outdir', mpath, '-output', [mname, '_mex']);
    end
end
