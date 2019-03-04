/*************************************************************************
 * Copyright 2019 Sebastian Merzbach
 *
 * authors:
 *  - Sebastian Merzbach <smerzbach@gmail.com>
 *
 * file creation date: 2019-03-03
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
 *************************************************************************
 * 
 * Matlab mex file for intersecting an array of rays with multiple
 * triangle meshes using Intel's Embree ray tracing kernels.
 * 
 * This code was heavily inspired by Alec Jacobsen's libigl
 * EmbreeIntersector.
 * 
 * This code has been tested with Embree version 2.17.7.
 */

// STL
#ifdef _MSC_VER
	#define _USE_MATH_DEFINES
#endif
#include <cmath>
#include <iostream>

// OpenMP for easy parallelization
#include <omp.h>

// Eigen matrix classes
#include <eigen3/Eigen/Core>

// Embree
#include <embree2/rtcore.h>
#include <embree2/rtcore_ray.h>

// MATLAB
#include <mex.h>

//#define VERBOSE
#ifdef VERBOSE
	#define LOG(message)		mexPrintf((std::string(message) + "\n").c_str())
	#define LOG_INFO(message)	mexPrintf((std::string("info: ") + message + std::string("\n")).c_str())
#else
	#define LOG(message)
	#define LOG_INFO(message)
#endif
#define LOG_WARNING(message) mexWarnMsgTxt((std::string(message) + std::string("\n")).c_str())
#define LOG_ERROR(message) mexErrMsgTxt((std::string(message) + std::string("\n")).c_str())

typedef Eigen::Matrix<float, Eigen::Dynamic, 3> MatrixNx3fType;
typedef Eigen::Matrix<int, Eigen::Dynamic, 3> MatrixNx3iType;
typedef Eigen::Map<Eigen::Matrix<float, Eigen::Dynamic, 3, Eigen::ColMajor> > mappedMatrixNx3fType;
typedef Eigen::Map<Eigen::Matrix<int, Eigen::Dynamic, 3, Eigen::ColMajor> > mappedMatrixNx3iType;
typedef Eigen::Map<Eigen::Matrix<int, Eigen::Dynamic, 2, Eigen::ColMajor> > mappedMatrixNx2iType;

static bool embree_initialized = false;
RTCDevice embree_device;
RTCScene embree_scene;

struct Vertex {
	float x, y, z, a;
};

struct Triangle {
	int v0, v1, v2;
};

// global storage for vertices & faces, so they can be reused over multiple mex calls
std::vector<Vertex*> vertices;
std::vector<Triangle*> triangles;

// meshes are individually specified as vertex & face matrices
std::vector<const mappedMatrixNx3fType*> vecVertexMats;
std::vector<const mappedMatrixNx3iType*> vecFaceMats;

// this becomes true once the geometry has been provided and processed by Embree
bool geometryLoaded = false;

void deleteGeometry() {
	if(embree_initialized && embree_scene) {
		rtcDeleteScene(embree_scene);
	}
	
	if(rtcDeviceGetError(embree_device) != RTC_NO_ERROR) {
		LOG_ERROR("Embree: An error occured while resetting!");
	#ifdef VERBOSE
	} else {
		LOG("Embree: geometry removed.");
	#endif
	}
}

// preproces geometry in Embree
inline void loadGeometry(const std::vector<const mappedMatrixNx3fType*>& V,
						 const std::vector<const mappedMatrixNx3iType*>& F,
						 const std::vector<int>& masks,
						 bool isStatic = true) {
	
	if (geometryLoaded) {
		deleteGeometry();
	}
	
	if(!embree_initialized) { 
		embree_device = rtcNewDevice();
		if(rtcDeviceGetError(embree_device) != RTC_NO_ERROR) {
			LOG_ERROR("Embree: An error occured while initialiting embree core!");
		#ifdef VERBOSE
		} else {
			LOG("Embree: core initialized.\n");
		#endif
		}
		embree_initialized = true;
	}
	
	if (V.size() == 0 || F.size() == 0) {
		LOG_ERROR("Embree: No geometry specified!");
	}
	
	// create a scene
	RTCSceneFlags flags = RTC_SCENE_ROBUST | RTC_SCENE_HIGH_QUALITY;
	if (isStatic) {
		flags = flags | RTC_SCENE_STATIC;
	}
	embree_scene = rtcDeviceNewScene(embree_device, flags, RTC_INTERSECT1);
	
	vertices.clear();
	vertices.resize(V.size());
	triangles.clear();
	triangles.resize(V.size());
	
	// iterate over meshes
	for (size_t m = 0; m < V.size(); m++) {
		LOG((std::string("creating new mesh with ") + std::to_string(F[m]->rows()) + " faces and " + std::to_string(V[m]->rows()) + " vertices").c_str());
		
		// create triangle mesh geometry in that scene
		unsigned geomtryID = rtcNewTriangleMesh(embree_scene, RTC_GEOMETRY_STATIC, F[m]->rows(), V[m]->rows(), 1);
		
		// fill vertex buffer
		vertices[m] = (Vertex*) rtcMapBuffer(embree_scene, geomtryID, RTC_VERTEX_BUFFER);
		for(size_t i = 0; i < V[m]->rows(); i++) {
			vertices[m][i].x = (float)V[m]->coeff(i, 0);
			vertices[m][i].y = (float)V[m]->coeff(i, 1);
			vertices[m][i].z = (float)V[m]->coeff(i, 2);
		}
		rtcUnmapBuffer(embree_scene, geomtryID, RTC_VERTEX_BUFFER);
		
		// fill triangle buffer
		triangles[m] = (Triangle*) rtcMapBuffer(embree_scene,geomtryID,RTC_INDEX_BUFFER);
		for(size_t i = 0; i < F[m]->rows(); i++) {
			triangles[m][i].v0 = (int)F[m]->coeff(i, 0);
			triangles[m][i].v1 = (int)F[m]->coeff(i, 1);
			triangles[m][i].v2 = (int)F[m]->coeff(i, 2);
		}
		rtcUnmapBuffer(embree_scene,geomtryID,RTC_INDEX_BUFFER);
		
		rtcSetMask(embree_scene,geomtryID,masks[m]);
	}
	
	rtcCommit(embree_scene);
	
	if(rtcDeviceGetError(embree_device) != RTC_NO_ERROR) {
		LOG_ERROR("Embree: An error occured while initializing the provided geometry!");
	#ifdef VERBOSE
	} else {
		LOG("Embree: geometry added.");
	#endif
	}
	geometryLoaded = true;
}

// clean up when MEX file is unloaded (e.g. vial "clear mex")
static void atExit() {
	deleteGeometry();
	embree_initialized = false;
	rtcDeleteDevice(embree_device);
	LOG("cleaning static variables.");
}

inline void createRay(RTCRay& ray, const Eigen::RowVector3f& origin, const Eigen::RowVector3f& direction, float tnear, float tfar, int mask) {
	ray.org[0] = origin[0];
	ray.org[1] = origin[1];
	ray.org[2] = origin[2];
	ray.dir[0] = direction[0];
	ray.dir[1] = direction[1];
	ray.dir[2] = direction[2];
	ray.tnear = tnear;
	ray.tfar = tfar;
	ray.geomID = RTC_INVALID_GEOMETRY_ID;
	ray.primID = RTC_INVALID_GEOMETRY_ID;
	ray.instID = RTC_INVALID_GEOMETRY_ID;
	ray.mask = mask;
	ray.time = 0.0f;
}

inline bool intersectRay(const Eigen::RowVector3f& origin,
						 const Eigen::RowVector3f& direction,
						 float t_near,
						 float t_far,
						 int mask,
						 size_t p,
						 mappedMatrixNx2iType& matIDs,
						 mappedMatrixNx3fType& matUVTs,
						 mappedMatrixNx3fType& matNormals) {
	RTCRay ray;
	createRay(ray, origin, direction, t_near, t_far, mask);
	
	// shot ray
	rtcIntersect(embree_scene, ray);
	#ifdef VERBOSE
		if(rtcGetError() != RTC_NO_ERROR) {
			LOG_ERROR("Embree: An error occured while resetting!");
		}
	#endif
	
	// initialize outputs
	matIDs(p, 0) = -1;
	matIDs(p, 1) = -1;
	matUVTs(p, 0) = -1.f;
	matUVTs(p, 1) = -1.f;
	matUVTs(p, 2) = -1.f;
	matNormals(p, 0) = 0.f;
	matNormals(p, 1) = 0.f;
	matNormals(p, 2) = 0.f;
	
	if((unsigned)ray.geomID != RTC_INVALID_GEOMETRY_ID) {
		matIDs(p, 0) = ray.primID;
		matIDs(p, 1) = ray.geomID;
		matUVTs(p, 0) = ray.u;
		matUVTs(p, 1) = ray.v;
		matUVTs(p, 2) = ray.tfar;
		matNormals(p, 0) = ray.Ng[0];
		matNormals(p, 1) = ray.Ng[1];
		matNormals(p, 2) = ray.Ng[2];
		return true;
	}
	
	return false;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	// This is useful for debugging whether Matlab is caching the mex binary
	#ifdef VERBOSE
		mexPrintf("%s %s\n",__TIME__,__DATE__);
	#endif
	mexAtExit(atExit);
	
	try {
		if (nrhs != 2) {
			LOG_ERROR("nrhs != 2");
		}
		
		if (mxIsCell(prhs[0]) && mxIsCell(prhs[1])) {
			// initialization mode, vertices and faces are provided
		
			const size_t num_meshes = mxGetNumberOfElements(prhs[0]);
			if (!mxIsCell(prhs[0]) || !mxIsCell(prhs[1])) {
				LOG_ERROR("Vertex and face arrays must be specified as cell arrays of NV x 3 and NF x 3 matrices.");
			}
			if (num_meshes != mxGetNumberOfElements(prhs[1])) {
				LOG_ERROR("Vertex and face arrays must be specified as cell arrays of NV x 3 and NF x 3 matrices.");
			}
			
			
			vecVertexMats.resize(num_meshes);
			vecFaceMats.resize(num_meshes);
			std::vector<int> vecMasks(num_meshes, 0xFFFFFFFF);
			for (size_t ii = 0; ii < num_meshes; ii++) {
				mxArray* pMatVertices = mxGetCell(prhs[0], ii);
				mxArray* pMatFaces = mxGetCell(prhs[1], ii);
				
				// input checks
				if (mxGetN(pMatVertices) != 3) {
					LOG_ERROR((std::string("Mesh vertex list #%d must be #V by 3 list of vertex positions") + std::to_string(ii)).c_str());
				}
				if (3 != (int)mxGetN(pMatFaces)) {
					LOG_ERROR((std::string("Mesh facet size #%d must be 3") + std::to_string(ii)).c_str());
				}
				if (mxGetClassID(pMatVertices) != mxSINGLE_CLASS) {
					LOG_ERROR("vertices must be provided as single precision float array.");
				}
				if (mxGetClassID(pMatFaces) != mxINT32_CLASS) {
					LOG_ERROR("face indices must be provided as int32 array.");
				}
				
				// wrap in Eigen::Matrix
				mappedMatrixNx3fType* matVertices = new mappedMatrixNx3fType((float*) mxGetData(pMatVertices), mxGetM(pMatVertices), mxGetN(pMatVertices));
				vecVertexMats[ii] = matVertices;
				mappedMatrixNx3iType* matFaces = new mappedMatrixNx3iType((int*) mxGetData(pMatFaces), mxGetM(pMatFaces), mxGetN(pMatFaces));
				vecFaceMats[ii] = matFaces;
				
				LOG("done.");
			}
			
			LOG("initializing RTC.");
			loadGeometry(vecVertexMats, vecFaceMats, vecMasks, true);
			LOG("done.");
		} else {
			// raytracing mode, only ray origins and directions are provided
			if (!geometryLoaded) {
				LOG_ERROR("geometry must be initialized first, please provide cell arrays of vertex and face matrices.");
			}
			
			// input checks
			if (mxGetN(prhs[0]) != 3) {
				LOG_ERROR("Ray origin matrix must be #R x 3.");
			}
			if (mxGetN(prhs[1]) != 3) {
				LOG_ERROR("Ray direction matrix must be #R x 3.");
			}
			if (mxGetM(prhs[0]) != mxGetM(prhs[1])) {
				LOG_ERROR("Number of ray origins and directions must be the same.");
			}
			if (mxGetClassID(prhs[0]) != mxSINGLE_CLASS) {
				LOG_ERROR("ray origins must be provided as single precision float array.");
			}
			if (mxGetClassID(prhs[1]) != mxSINGLE_CLASS) {
				LOG_ERROR("ray directions must be provided as single precision float array.");
			}
			
			// wrap in Eigen::Matrix
			mappedMatrixNx3fType matOrigins((float*) mxGetData(prhs[0]), mxGetM(prhs[0]), mxGetN(prhs[0]));
			mappedMatrixNx3fType matDirs((float*) mxGetData(prhs[1]), mxGetM(prhs[1]), mxGetN(prhs[1]));
			int num_rays = matOrigins.rows();
			
			// create output matrices
			plhs[0] = mxCreateUninitNumericMatrix(num_rays, 2, mxINT32_CLASS, mxREAL);
			int* pi_primGeomIDs = (int*) mxGetData(plhs[0]);
			
			plhs[1] = mxCreateUninitNumericMatrix(num_rays, 3, mxSINGLE_CLASS, mxREAL);
			float* pf_UVTs = (float*) mxGetData(plhs[1]);
			
			plhs[2] = mxCreateUninitNumericMatrix(num_rays, 3, mxSINGLE_CLASS, mxREAL);
			float* pf_Normals = (float*) mxGetData(plhs[2]);
			
			mappedMatrixNx2iType matPrimGeomIDs(pi_primGeomIDs, num_rays, 2);
			mappedMatrixNx3fType matUVTs(pf_UVTs, num_rays, 3);
			mappedMatrixNx3fType matNormals(pf_Normals, num_rays, 3);
			
			// the actual intersection tests happen here
			float t_near = 1e-4f;
			float t_far = std::numeric_limits<float>::infinity();
			int mask = 0xFFFFFFFF;
			#pragma omp parallel for
			for (size_t p = 0; p < num_rays; p++) {
				const Eigen::Vector3f origin = matOrigins.row(p);
				const Eigen::Vector3f dir = matDirs.row(p);
				
				intersectRay(origin, dir, t_near, t_far, mask, p, matPrimGeomIDs, matUVTs, matNormals);
			}
		}
	} catch( std::exception& e ) {
		LOG_ERROR(e.what());
	}
}
