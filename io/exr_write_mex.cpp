/**************************************************************************
 * Copyright 2017 Sebastian Merzbach
 *
 * authors:
 *  - Sebastian Merzbach <smerzbach@gmail.com>
 *
 * file creation date: 2017-11-26
 *
 * This file is part of smml.
 *
 * smml is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * smml is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with smml.  If not, see <http://www.gnu.org/licenses/>.
 *
 **************************************************************************
 *
 * Mex file for writing images in OpenEXR format. Usage:
 *
 * exr_write_mex(image, filename[, output_pixel_type[, ...
 *    write_half[, channel_names]]]),
 *
 * where:
 * - image is is a 2D or 3D array of floats, uint32s or uint16s (for half
 *   precision floats)
 * - the optional argument output_pixel_type enforces the data to be
 *   written as the specified data type, possible values are 'single',
 *   'half' or 'uint'
 * - channel_names is a cell array of strings holding the names of each
 *   channel
 */

#include <string>
#include <vector>

#include <mex.h>

#define TINYEXR_IMPLEMENTATION
#include "../external/tinyexr/tinyexr.h"

#ifdef _MSC_VER
#define strncpy_s strncpy
#endif

void mexFunction(int nlhs, mxArray *plhs[],int nrhs, const mxArray *prhs[]) {
    // check & parse inputs
    if (nlhs != 0) {
        mexErrMsgTxt("Function does not return any outputs.");
    }
    
    if (nrhs != 5) {
        mexErrMsgTxt("Usage: exr.write_mex(image, filename, output_pixel_type, channel_names, compression);");
    }
    
    if (!mxIsChar(prhs[1])) {
        mexErrMsgTxt("Second input argument must be a string.");
    }
    
    if (!mxIsCell(prhs[3]) || mxIsEmpty(prhs[3])) {
        mexErrMsgTxt("input must either be M x N x 3 or M x N x P and a cell array of P strings specifying the channel names.");
    }
    
    char *filename = mxArrayToString(prhs[1]);
    int output_pixel_type = (int) mxGetScalar(prhs[2]); // 0: UINT, 1: HALF, 2: FLOAT
    const mxArray* mx_channels = prhs[3];
    mwSize num_channel_names = mxGetNumberOfElements(mx_channels);
    int compression = (int) mxGetScalar(prhs[4]);
    
    int ndims = mxGetNumberOfDimensions(prhs[0]);
    if (ndims < 2 || ndims > 3) {
        mexErrMsgTxt("First input argument must be a 2D or 3D array.");
    }
    const mwSize* dims = mxGetDimensions(prhs[0]);
    size_t height = dims[0];
    size_t width = dims[1];
    size_t num_channels = 1;
    if (ndims == 3 && mxIsCell(prhs[3])) {
        num_channels = dims[2];
    }
    
    if (num_channels != num_channel_names) {
        mexErrMsgTxt("Number of image channels must match number of channel names!");
    }
    
    if (mxGetClassID(prhs[0]) != mxSINGLE_CLASS
            && mxGetClassID(prhs[0]) != mxUINT16_CLASS
            && mxGetClassID(prhs[0]) != mxUINT32_CLASS) {
        mexErrMsgTxt("First input argument must be in single or uint16 precision.");
    }
    
    // conversion from lower to higher precision doesn't make sense (except for uint16 -> uint32)
    if (output_pixel_type == TINYEXR_PIXELTYPE_FLOAT && 
            (mxGetClassID(prhs[0]) == mxUINT16_CLASS
            || mxGetClassID(prhs[0]) == mxUINT32_CLASS)) {
        mexErrMsgTxt("If the image array is in uint16 (or half) or uint32 format, precision must be set to 'half' or 'uint'.");
    }
    
    if (!mxIsScalar(prhs[4]) || 0 > compression || compression > 4) {
        mexErrMsgTxt("compression argument must be an integer between 0 and 4.");
    }
    
    // assume at least 16x16 pixels
    if (width < 16 || height < 16) {
        mexErrMsgTxt("input image must be at least 16x16 pixels.");
    }
    
    EXRHeader header;
    EXRImage image;
    InitEXRHeader(&header);
    InitEXRImage(&image);
    
    image.width = width;
    image.height = height;
    image.num_channels = num_channels;
    
    // convert Matlab's column-major to row-major format & provide pointers per channel
    std::vector<unsigned char*> image_ptrs(num_channels);
    std::vector<float> data_float;
    std::vector<uint16_t> data_half;
    std::vector<uint32_t> data_uint;
    int pixel_type = -1;
    if (mxGetClassID(prhs[0]) == mxSINGLE_CLASS) {
        pixel_type = TINYEXR_PIXELTYPE_FLOAT;
        float* data = (float*) mxGetData(prhs[0]);
        data_float.resize(height * width * num_channels);
        for (size_t ci = 0; ci < num_channels; ci++) {
            // transpose x and y
            for (size_t y = 0; y < height; y++) {
                for (size_t x = 0; x < width; x++) {
                    data_float[ci * height * width + y * width + x] = 
                            data[ci * height * width + x * height + y];
                }
            }
            image_ptrs[ci] = (unsigned char*) (&(data_float[ci * width * height]));
        }
    } else if (mxGetClassID(prhs[0]) == mxUINT16_CLASS) {
        pixel_type = TINYEXR_PIXELTYPE_HALF;
        uint16_t* data = (uint16_t*) mxGetData(prhs[0]);
        data_half.resize(height * width * num_channels);
        for (size_t ci = 0; ci < num_channels; ci++) {
            // transpose x and y
            for (size_t y = 0; y < height; y++) {
                for (size_t x = 0; x < width; x++) {
                    data_half[ci * height * width + y * width + x] = 
                            data[ci * height * width + x * height + y];
                }
            }
            image_ptrs[ci] = (unsigned char*) (&(data_half[ci * width * height]));
        }
    } else if (mxGetClassID(prhs[0]) == mxUINT32_CLASS) {
        pixel_type = TINYEXR_PIXELTYPE_UINT;
        uint32_t* data = (uint32_t*) mxGetData(prhs[0]);
        data_uint.resize(height * width * num_channels);
        for (size_t ci = 0; ci < num_channels; ci++) {
            // transpose x and y
            for (size_t y = 0; y < height; y++) {
                for (size_t x = 0; x < width; x++) {
                    data_uint[ci * height * width + y * width + x] = 
                            data[ci * height * width + x * height + y];
                }
            }
            image_ptrs[ci] = (unsigned char*) (&(data_uint[ci * width * height]));
        }
    } else {
        mexErrMsgTxt("unsupported pixel type, must be single, uint16 (half) or uint32.\n");
    }
    image.images = &(image_ptrs[0]);
    
    // set channel names & formats
    header.num_channels = num_channels;
    header.channels = new EXRChannelInfo[num_channels];
    header.pixel_types = new int[num_channels];
    header.requested_pixel_types = new int[num_channels];
    for (size_t ci = 0; ci < num_channels; ci++) {
        char* channel_name = mxArrayToString(mxGetCell(mx_channels, ci));
        strncpy(header.channels[ci].name, channel_name, 255);
        
        // set input pixel format
        header.pixel_types[ci] = pixel_type;
        
        // set file storage format
        header.requested_pixel_types[ci] = output_pixel_type;
    }
    
    // set compression type
    header.compression_type = compression;
    
    const char *err;
    int ret = SaveEXRImageToFile(&image, &header, filename, &err);
    if (ret != TINYEXR_SUCCESS) {
        mexErrMsgTxt((std::string("error in writing EXR file ") + std::string(filename) + 
                std::string(", return code: ") + std::to_string(ret) + 
                std::string(", error message: ") + std::string(err)).c_str());
    }
    
    delete[] header.channels;
    delete[] header.pixel_types;
    delete[] header.requested_pixel_types;
}
