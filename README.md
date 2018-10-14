# matlabtools
Collection of Matlab toolset, including:
  * mex automatic compilation: `mex_auto()`
  * convenient helpers: `col()`, `row()`, `afun()`, `cfun()`, `cat2()`, `mat2cell2()`, `collage()`, `default()`, `arg()`, `strparse()`, ...
  * OpenEXR reader & writer, supporting multichannel (e.g. spectral) images, based on tinyexr.h, i.e. header-only compilation: `exr_read()`, `exr_write()`, `exr_query()`
  * embeddable HDR image viewer: `iv()`
  * tonemapping widget: `tonemapper()`
  * zoomable & scrollable axes: `zoomaxes()`
  * spectral image viewer: `sv()`

## `mex_auto()` - hands-free, on-demand mex-compilation
Tired of calling `mex` from hand or looking for build scripts every time you've changed your C/C++ code?
Add a simple m-script as generic wrapper and put a call to `mex_auto()` in it:

```matlab
% bla.m
function varargout = bla(varargin)
    % trigger automatic compilation of bla_mex.cpp if bla_mex.mexa64 is older or non-existent
    mex_auto();
    
    varargout = cell(1, nargout);
    % the actual call to the compiled library
    [varargout{:}] = bla_mex(varargin{:});
end
```

`mex_auto()` by default looks for `bla_mex.cpp` and `bla_mex.mexa64` (or the equivalents on Windows / Mac), and builds `bla_mex.cpp` if it hasn't been compiled or the source is newer than the compiled library.

**WARNING**: You might want to comment out the call to `mex_auto()` for production use if you frequently call your function, as it introduces a noticable overhead!

More complex compiler instructions, e.g. multiple source files can be specified by the following name-value pairs:
  * mex_file: desired name of the compiled MEX file, defaults to `['caller_mex', mexext]`
  * sources:  cell array of C/C++/Fortran files that need to be compiled, defaults to 'caller_mex.cpp' or 'caller_mex.c'
  * headers:  additional cell array of header files whose modification time stamps should be checked (not passed to `mex()`)
  * openmp:   set to true if you want to compile with OpenMP support
  * cpp11:    set to true (default) to enable the C++11 standard
  
Any further inputs are directly passed to `mex()`.

 More complex example with multiple source files:

```matlab
% bla.m:
function varargout = bla(varargin)
    mex_auto('sources', {'main_source.cpp', 'other_source.cpp'}, ...
        'headers', {'main_header.h', 'other_header.hpp', 'yet_another_header.h'}, ...
        'mex_file', 'bla_compiled'); % this call will trigger automatic
        % compilation of bla_main.cpp and other_source.cpp if necessary
    
    varargout = cell(1, nargout);
    % now call the compiled MEX file
    [varargout{:}] = bla_compiled(varargin{:});
end
```

As stated above and shown in the examples, using mex_auto requires that you maintain an additional
m-file besides your C/C++ code that calls mex_auto() and the compiled MEX function. However, with
a simple pattern shown in the examples below, you won't have to deal explicitly with input and
output arguments. Even better, having an accompanying m-file for your source code is a good idea
in general, as it is so much nicer to do input checks and parsing in Matlab than in C/C++!
Besides that, you can use the m-file to display help texts, which is not possible with compilable
source code only.

# convenience functions
Matlab's toolset is great and all, but some of its functions have annoying syntaxes that drive you
crazy during every-day usage.
The following list shows alternatives that try to avoid these every-day annoyances:

## `col()` & `row()`
Inline unrolling into column and row vectors:
```matlab
>> c = col(1 : 10)
c =
     1
     2
     3
     4
     5
     6
     7
     8
     9
    10
>> row(c)
ans =
     1     2     3     4     5     6     7     8     9    10
```
## `cellfun()` &rarr; `cfun()`
`cellfun()` provides a nice way to apply a function to all elements of one or multiple cell arrays
and can either return one or multiple arrays obtained by concatenating scalar valued output
arguments, or throw an error when the outputs cannot be concatenated because they're not homogenous
scalars. In this case, one has to specify an additional name-value pair to make 
`cellfun(..., 'UniformOutput', false)` concatenate the outputs as a cell array instead.
For those who are tired of typing this, there is `cfun()`, which is just a wrapper around `cellfun()`
with 'UniformOutput' set to false.

## `arrayfun()` &rarr; `afun()`
`arrayfun` has exactly the same problem and is therefore wrapped by `afun()`.

## `cat()` &rarr; `cat2()`
`cat()` provides control along which dimension multiple inputs should be concatenated, which comes
particularly handy in case of cell arrays: `cat(3, channels{:})` concatenates all arrays in `channels`
along the third dimension. If, however, cat is to be used with an inline function call, it won't work
because there is no way except the `{:}` operator to expand an array in place. `cat2()` to the rescue:
`cat2(3, function_generating_channels())` is equivalent to
```matlab
channels = function_generating_channels();
cat(3, channels{:});
```

## `mat2cell()` &rarr; `mat2cell2()`
`mat2cell()` is great for splitting normal arrays into sub-arrays and concatenating those in a cell array.
Sadly, its usage is annoying as all sub-array dimensions have to be specified explicitly for all input dimensions:
`array = ones(30, 60, 3); mat2cell(array, [10, 10, 10], [30, 30], size(array, 3));`. Though this allows
for maximum flexibility, in most cases it is unnecessarily complicated.
The following wrapper reduces the complexity a lot:
`mat2cell2(array, 10, 30, size(array, 3));` sub-array dimensions have to be specified only once (this of course only works
when all sub-arrays have the same size). Additionally, dimensions that should not be split at all, can be
skipped by specifying an empty array `[]`: `mat2cell2(array, 10, 30, [])`.
This comes in handy when an image needs to be split into its channels:
```matlab
image = rand(100, 200, 3);
channels = mat2cell2(image, [], [], 1);
>> channels(:)

ans =

  3×1 cell array

    {100×200 double}
    {100×200 double}
    {100×200 double}
```

## `collage()`
Suppose you used `mat2cell2()` to create many small patches from an image and apply a function to each patch
using `cfun()`. You then often want to inspect each patch, or even better, all patches at once. In comes `collage()`:
```matlab
image = imread('cameraman.tif');
patches = mat2cell2(image, 16, 16, 1);
patches = cfun(@(patch) fliplr(patch), patches);
% quickly inspect transformed patches
tmp = double(collage(patches, 'transpose', false));
figure; imshow(tmp / 255);
tmp = double(collage(patches, 'border_width', 1, 'transpose', false));
figure; imshow(tmp / 255);
```
![](examples/cameraman.jpg) ![](examples/cameraman_collage.jpg) ![](examples/cameraman_collage_border.jpg)

The purpose of `collage()` is similar to Matlab's montage(), only that it concatenates the inputs into an array,
instead of displaying them together.
If not specified explicitly (`'nr'` and `'nc'`), it attempts arranging them in a square manner.
Optionally, a border can be added between the patches (`'border_width'`) with a specific value (`'border_value'`).

## `nargin` / `exist()` &rarr; `default()`
When checking if specific input arguments are set, there are two options (if not using something more involved like `inputParser`):
```matlab
function bla(input1, input2)
    if nargin < 2
        % assign default value
        input2 = 2;
    end
    
    % or:
    if ~exist('input2', 'var')
        input2 = 2;
    end
    ...
end
```
Both options involve a lot of code, which becomes even more when additional checks are involved.
The wrapper `default()` saves all that hassle and condenses it in one line:
```matlab
function bla(input1, input2)
    input2 = default('input2', 2);
    
    % is equivalent to:
    if ~exist('input2', 'var') || isempty(input2)
        input2 = 2;
    end
end
```
Though it looks like it, input2 is *not* overwritten by the above call to `default()`.
This works by checking for existence of `input2` in the calling function using `evalin('caller', ...)`.
The default value `2` is only assigned if the variable `input2` does not yet exist inside `bla()`'s scope,
or if it is empty.

**WARNING**: `default()` causes significant overhead and therefore should be avoided in functions that are called
very frequently (e.g. many rapid calls inside a for loop)! It is great for specifying arguments once in a main script.

## `inputParser` &rarr; `arg()`
Matlab's `inputParser` is powerful, but often way to complex. If the only job is to parse name-value pairs from
`varargin`, `arg()` is much easier to use:
```matlab
function bla(input1, varargin)
  [varargin, arg1] = arg(varargin, 'arg1', 2);
  [varargin, width, height, depth] = arg(varargin, {'width', 'height', 'depth'}, {-1, -2, -3});
  ...
end
```
This looks for occurrence of the specified named argument inside `varargin`, and assigns a default value if it is missing.
Multiple named arguments can be listed along with their respective default values in one call.

## `strparse`
Parse (multiple) substrings from a cell array of strings using regular expressions, optionally converting to numeric arrays.
```matlab
>> fnames = afun(@(number) sprintf('prefix_num%03d_prop%03.2f.txt', number, 1000 * (rand() - 0.5)), col(1 : 10))
fnames =
  10×1 cell array
    {'prefix_num001_prop314.72.txt' }
    {'prefix_num002_prop405.79.txt' }
    {'prefix_num003_prop-373.01.txt'}
    {'prefix_num004_prop413.38.txt' }
    {'prefix_num005_prop132.36.txt' }
    {'prefix_num006_prop-402.46.txt'}
    {'prefix_num007_prop-221.50.txt'}
    {'prefix_num008_prop46.88.txt'  }
    {'prefix_num009_prop457.51.txt' }
    {'prefix_num010_prop464.89.txt' }
>> [num, prop] = strparse(fnames, 'prefix_num(\d+)_prop(-?\d+\.\d+).txt')
num =
  10×1 cell array
    {'001'}
    {'002'}
    {'003'}
    {'004'}
    {'005'}
    {'006'}
    {'007'}
    {'008'}
    {'009'}
    {'010'}
prop =
  10×1 cell array
    {'314.72' }
    {'405.79' }
    {'-373.01'}
    {'413.38' }
    {'132.36' }
    {'-402.46'}
    {'-221.50'}
    {'46.88'  }
    {'457.51' }
    {'464.89' }
>> [num, prop] = strparse(fnames, 'prefix_num(\d+)_prop(-?\d+\.\d+).txt', true)
num =
     1
     2
     3
     4
     5
     6
     7
     8
     9
    10
prop =
  314.7200
  405.7900
 -373.0100
  413.3800
  132.3600
 -402.4600
 -221.5000
   46.8800
  457.5100
  464.8900
```
## 