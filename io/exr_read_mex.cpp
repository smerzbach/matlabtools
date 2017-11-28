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
 * Mex file for reading images in OpenEXR format. Usage:
 *
 * [image, channel_names] = exr_read_mex(filename, to_single), where
 * - the optional argument to_single determines if the pixel values should
 *   be converted to single precision floats, even if they are stored as
 *   unsigned integers or as half precision floats in the file
 * - image is is a 2D or 3D array of floats or unsigned integers (also for
 *   half precision floats)
 * - channel_names is a cell array of strings holding the names of each
 *   channel
 */ 

#include <cstdint>
#include <string>
#include <vector>

#include <mex.h>

#define TINYEXR_IMPLEMENTATION
#include "tinyexr.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // check inputs
    if(1 > nrhs || nrhs > 2) {
        mexErrMsgTxt("Usage: [im, channels] = exr_read(path_to_exr_file[, requested_pixel_type])");
    }
    
    // read inputs
    char *filename = mxArrayToString(prhs[0]);
    
    int requested_pixel_type = TINYEXR_PIXELTYPE_FLOAT;
    if (nrhs > 1) {
        requested_pixel_type = mxGetScalar(prhs[1]);
    }
    
    if (0 > requested_pixel_type || requested_pixel_type > 2) {
        mexErrMsgTxt("requested_pixel_type must be 0 (uint), 1 (half) or 2 (float).\n");
    }
    
    try {
        EXRVersion exr_version;
        EXRImage exr_image;
        EXRHeader exr_header;
        InitEXRHeader(&exr_header);
        InitEXRImage(&exr_image);

        // read EXR format from file & check for compatibility
        int ret = ParseEXRVersionFromFile(&exr_version, filename);
        if (ret != TINYEXR_SUCCESS) {
            mexErrMsgTxt((std::string("Error parsing EXR version from file ") + 
                    std::string(filename) + std::string(". Not an OpenEXR file?")).c_str());
        }
        if (exr_version.multipart || exr_version.non_image) {
            mexErrMsgTxt("Loading multipart or DeepImage is not supported yet.\n");
        }

        // read meta data from EXR file
        const char** err;
        ret = ParseEXRHeaderFromFile(&exr_header, &exr_version, filename, err);
        if (ret != TINYEXR_SUCCESS) {
            mexErrMsgTxt("parsing header from file failed.\n");
        }

        // set requested pixel type (uint, half or float)
        for (size_t i = 0; i < exr_header.num_channels; i++) {
            if (exr_header.pixel_types[i] == TINYEXR_PIXELTYPE_HALF) {
                exr_header.requested_pixel_types[i] = requested_pixel_type;
            }
        }

        size_t height = exr_header.data_window[3] - exr_header.data_window[1] + 1;
        size_t width  = exr_header.data_window[2] - exr_header.data_window[0] + 1;
        size_t channels = exr_header.num_channels;
        
        // read pixel values from EXR file
        ret = LoadEXRImageFromFile(&exr_image, &exr_header, filename, err);
        if (ret != 0) {
            mexErrMsgTxt((std::string("Load EXR error: ") + std::string(*err)).c_str());
        }
        
        // set dimensions of Matlab array
        mwSize dims[3];
        dims[0] = height;
        dims[1] = width;
        dims[2] = channels;
        
        // copy pixel values to Matlab array
        if (requested_pixel_type == TINYEXR_PIXELTYPE_FLOAT) {
            plhs[0] = mxCreateNumericArray(3, dims, mxSINGLE_CLASS, mxREAL);
            float* outMatrix = (float*) mxGetData(plhs[0]);
            float** images = (float**) exr_image.images;
            for (size_t ci = 0; ci < channels; ci++) {
                for (size_t x = 0; x < width; x++) {
                    for (size_t y = 0; y < height; y++) {
                        outMatrix[height * width * ci + x * height + y] = 
                                images[ci][x + y * width];
                    }
                }
            }
        } else if (requested_pixel_type == TINYEXR_PIXELTYPE_HALF) {
            plhs[0] = mxCreateNumericArray(3, dims, mxUINT16_CLASS, mxREAL);
            unsigned short* outMatrix = (unsigned short*) mxGetData(plhs[0]);
            unsigned short** images = (unsigned short**) exr_image.images;
            for (size_t ci = 0; ci < channels; ci++) {
                for (size_t x = 0; x < width; x++) {
                    for (size_t y = 0; y < height; y++) {
                        outMatrix[height * width * ci + x * height + y] = 
                                images[ci][x + y * width];
                    }
                }
            }
        } else {
            plhs[0] = mxCreateNumericArray(3, dims, mxUINT32_CLASS, mxREAL);
            unsigned int* outMatrix = (unsigned int*) mxGetData(plhs[0]);
            unsigned int** images = (unsigned int**) exr_image.images;
            for (size_t ci = 0; ci < channels; ci++) {
                for (size_t x = 0; x < width; x++) {
                    for (size_t y = 0; y < height; y++) {
                        outMatrix[height * width * ci + x * height + y] = 
                                images[ci][x + y * width];
                    }
                }
            }
        }

        // extract channel names
        if (nlhs > 1) {
            dims[0] = 1;
            dims[1] = channels;

            plhs[1] = mxCreateCellArray(2, dims);
            for (size_t ci = 0; ci < channels; ci++) {
                mxSetCell(plhs[1], ci, mxDuplicateArray(mxCreateString(exr_header.channels[ci].name)));
            }
        }

        FreeEXRImage(&exr_image);
        FreeEXRHeader(&exr_header);
    } catch (std::runtime_error err) {
        mexErrMsgTxt((std::string("error reading EXR file ") + 
                std::string(filename) + std::string("\n")).c_str());
    }
}
