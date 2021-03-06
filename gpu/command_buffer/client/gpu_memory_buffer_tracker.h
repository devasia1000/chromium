// Copyright (c) 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef GPU_COMMAND_BUFFER_CLIENT_GPU_MEMORY_BUFFER_TRACKER_H_
#define GPU_COMMAND_BUFFER_CLIENT_GPU_MEMORY_BUFFER_TRACKER_H_

#include <GLES2/gl2.h>

#include "../client/hash_tables.h"
#include "base/basictypes.h"
#include "gles2_impl_export.h"

namespace gpu {
class GpuMemoryBuffer;

namespace gles2 {
class ImageFactory;

// Tracks GPU memory buffer objects on the client side.
class GLES2_IMPL_EXPORT GpuMemoryBufferTracker {
 public:
  // Ownership of |factory| remains with caller.
  explicit GpuMemoryBufferTracker(ImageFactory* factory);
  virtual ~GpuMemoryBufferTracker();

  GLuint CreateBuffer(
      GLsizei width, GLsizei height, GLenum internalformat);
  GpuMemoryBuffer* GetBuffer(GLuint image_id);
  void RemoveBuffer(GLuint image_id);

 private:
  typedef gpu::hash_map<GLuint, GpuMemoryBuffer*> BufferMap;
  BufferMap buffers_;
  ImageFactory* factory_;

  DISALLOW_COPY_AND_ASSIGN(GpuMemoryBufferTracker);
};

}  // namespace gles2
}  // namespace gpu

#endif  // GPU_COMMAND_BUFFER_CLIENT_GPU_MEMORY_BUFFER_TRACKER_H_
