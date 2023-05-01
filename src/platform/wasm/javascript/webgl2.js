/** @export */
IsWebGL2: () => {
  return (this.ctxVersion >= 2)
},

/* Buffer objects */
/** @export */
CopyBufferSubData: (readTarget, writeTarget, readOffset, writeOffset, size) => {
  this.ctx.copyBufferSubData(readTarget, writeTarget, readOffset, writeOffset, size);
},
/** @export */
GetBufferSubData: (target, srcByteOffset, dst_buffer_ptr, dst_buffer_len, dstOffset, length) => {
  this.ctx.getBufferSubData(target, srcByteOffset, this.mem.loadBytes(dst_buffer_ptr, dst_buffer_len), dstOffset, length);
},

/* Framebuffer objects */
/** @export */
BlitFramebuffer: (srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1, mask, filter) => {
  this.ctx.glitFramebuffer(srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1, mask, filter);
},
/** @export */
FramebufferTextureLayer: (target, attachment, texture, level, layer) => {
  this.ctx.framebufferTextureLayer(target, attachment, this.textures[texture], level, layer);
},
/** @export */
InvalidateFramebuffer: (target, attachments_ptr, attachments_len) => {
  let attachments = this.mem.loadU32Array(attachments_ptr, attachments_len);
  this.ctx.invalidateFramebuffer(target, attachments);
},
/** @export */
InvalidateSubFramebuffer: (target, attachments_ptr, attachments_len, x, y, width, height) => {
  let attachments = this.mem.loadU32Array(attachments_ptr, attachments_len);
  this.ctx.invalidateSubFramebuffer(target, attachments, x, y, width, height);
},
/** @export */
ReadBuffer: (src) => {
  this.ctx.readBuffer(src);
},

/* Renderbuffer objects */
/** @export */
RenderbufferStorageMultisample: (target, samples, internalformat, width, height) => {
  this.ctx.renderbufferStorageMultisample(target, samples, internalformat, width, height);
},

/* Texture objects */

/** @export */
TexStorage3D: (target, level, internalformat, width, height, depth) => {
  this.ctx.texStorage3D(target, level, internalformat, width, height, depth);
},
/** @export */
TexImage3D: (target, level, internalformat, width, height, depth, border, format, type, size, data) => {
  if (data) {
    this.ctx.texImage3D(target, level, internalformat, width, height, depth, border, format, type, this.mem.loadBytes(data, size));
  } else {
    this.ctx.texImage3D(target, level, internalformat, width, height, depth, border, format, type, null);
  }
},
/** @export */
TexSubImage3D: (target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, size, data) => {
  this.ctx.texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, this.mem.loadBytes(data, size));
},
/** @export */
CompressedTexImage3D: (target, level, internalformat, width, height, depth, border, imageSize, data) => {
  if (data) {
    this.ctx.compressedTexImage3D(target, level, internalformat, width, height, depth, border, this.mem.loadBytes(data, imageSize));
  } else {
    this.ctx.compressedTexImage3D(target, level, internalformat, width, height, depth, border, null);
  }
},
/** @export */
CompressedTexSubImage3D: (target, level, xoffset, yoffset, zoffset, width, height, depth, format, imageSize, data) => {
  if (data) {
    this.ctx.compressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, this.mem.loadBytes(data, imageSize));
  } else {
    this.ctx.compressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, null);
  }
},

/** @export */
CopyTexSubImage3D: (target, level, xoffset, yoffset, zoffset, x, y, width, height) => {
  this.ctx.copyTexImage3D(target, level, xoffset, yoffset, zoffset, x, y, width, height);
},

/* Programs and shaders */
/** @export */
GetFragDataLocation: (program, name_ptr, name_len) => {
  return this.ctx.getFragDataLocation(this.programs[program], this.mem.loadString(name_ptr, name_len));
},

/* Uniforms */
/** @export */
Uniform1ui: (location, v0) => {
  this.ctx.uniform1ui(this.uniforms[location], v0);
},
/** @export */
Uniform2ui: (location, v0, v1) => {
  this.ctx.uniform2ui(this.uniforms[location], v0, v1);
},
/** @export */
Uniform3ui: (location, v0, v1, v2) => {
  this.ctx.uniform3ui(this.uniforms[location], v0, v1, v2);
},
/** @export */
Uniform4ui: (location, v0, v1, v2, v3) => {
  this.ctx.uniform4ui(this.uniforms[location], v0, v1, v2, v3);
},

/** @export */
UniformMatrix3x2fv: (location, addr) => {
  let array = this.mem.loadF32Array(addr, 3*2);
  this.ctx.uniformMatrix3x2fv(this.uniforms[location], false, array);
},
/** @export */
UniformMatrix4x2fv: (location, addr) => {
  let array = this.mem.loadF32Array(addr, 4*2);
  this.ctx.uniformMatrix4x2fv(this.uniforms[location], false, array);
},
/** @export */
UniformMatrix2x3fv: (location, addr) => {
  let array = this.mem.loadF32Array(addr, 2*3);
  this.ctx.uniformMatrix2x3fv(this.uniforms[location], false, array);
},
/** @export */
UniformMatrix4x3fv: (location, addr) => {
  let array = this.mem.loadF32Array(addr, 4*3);
  this.ctx.uniformMatrix4x3fv(this.uniforms[location], false, array);
},
/** @export */
UniformMatrix2x4fv: (location, addr) => {
  let array = this.mem.loadF32Array(addr, 2*4);
  this.ctx.uniformMatrix2x4fv(this.uniforms[location], false, array);
},
/** @export */
UniformMatrix3x4fv: (location, addr) => {
  let array = this.mem.loadF32Array(addr, 3*4);
  this.ctx.uniformMatrix3x4fv(this.uniforms[location], false, array);
},

/* Vertex attribs */
/** @export */
VertexAttribI4i: (index, x, y, z, w) => {
  this.ctx.vertexAttribI4i(index, x, y, z, w);
},
/** @export */
VertexAttribI4ui: (index, x, y, z, w) => {
  this.ctx.vertexAttribI4ui(index, x, y, z, w);
},
/** @export */
VertexAttribIPointer: (index, size, type, stride, offset) => {
  this.ctx.vertexAttribIPointer(index, size, type, stride, offset);
},

/* Writing to the drawing buffer */
/** @export */
VertexAttribDivisor: (index, divisor) => {
  this.ctx.vertexAttribDivisor(index, divisor);
},
/** @export */
DrawArraysInstanced: (mode, first, count, instanceCount) => {
  this.ctx.drawArraysInstanced(mode, first, count, instanceCount);
},
/** @export */
DrawElementsInstanced: (mode, count, type, offset, instanceCount) => {
  this.ctx.drawElementsInstanced(mode, count, type, offset, instanceCount);
},
/** @export */
DrawRangeElements: (mode, start, end, count, type, offset) => {
  this.ctx.drawRangeElements(mode, start, end, count, type, offset);
},

/* Multiple Render Targets */
/** @export */
DrawBuffers: (buffers_ptr, buffers_len) => {
  let array = this.mem.loadU32Array(buffers_ptr, buffers_len);
  this.ctx.drawBuffers(array);
},
/** @export */
ClearBufferfv: (buffer, drawbuffer, values_ptr, values_len) => {
  let array = this.mem.loadF32Array(values_ptr, values_len);
  this.ctx.clearBufferfv(buffer, drawbuffer, array);
},
/** @export */
ClearBufferiv: (buffer, drawbuffer, values_ptr, values_len) => {
  let array = this.mem.loadI32Array(values_ptr, values_len);
  this.ctx.clearBufferiv(buffer, drawbuffer, array);
},
/** @export */
ClearBufferuiv: (buffer, drawbuffer, values_ptr, values_len) => {
  let array = this.mem.loadU32Array(values_ptr, values_len);
  this.ctx.clearBufferuiv(buffer, drawbuffer, array);
},
/** @export */
ClearBufferfi: (buffer, drawbuffer, depth, stencil) => {
  this.ctx.clearBufferfi(buffer, drawbuffer, depth, stencil);
},

/* Query Objects */
/** @export */
CreateQuery: () => {
  let query = this.ctx.createQuery();
  let id = this.getNewId(this.queries);
  query.name = id;
  this.queries[id] = query;
  return id;
},
/** @export */
DeleteQuery: (id) => {
  let obj = this.queries[id];
  if (obj && id != 0) {
    this.ctx.deleteQuery(obj);
    this.queries[id] = null;
  }
},
/** @export */
IsQuery: (query) => {
  return this.ctx.isQuery(this.queries[query]);
},
/** @export */
BeginQuery: (target, query) => {
  this.ctx.beginQuery(target, this.queries[query])
},
/** @export */
EndQuery: (target) => {
  this.ctx.endQuery(target);
},
/** @export */
GetQuery: (target, pname) => {
  let query = this.ctx.getQuery(target, pname);
  if (!query) {
    return 0;
  }
  if (this.queries.indexOf(query) !== -1) {
    return query.name;
  }
  let id = this.getNewId(this.queries);
  query.name = id;
  this.queries[id] = query;
  return id;
},

/* Sampler Objects */
/** @export */
CreateSampler: () => {
  let sampler = this.ctx.createSampler();
  let id = this.getNewId(this.samplers);
  sampler.name = id;
  this.samplers[id] = sampler;
  return id;
},
/** @export */
DeleteSampler: (id) => {
  let obj = this.samplers[id];
  if (obj && id != 0) {
    this.ctx.deleteSampler(obj);
    this.samplers[id] = null;
  }
},
/** @export */
IsSampler: (sampler) => {
  return this.ctx.isSampler(this.samplers[sampler]);
},
/** @export */
BindSampler: (unit, sampler) => {
  this.ctx.bindSampler(unit, this.samplers[sampler]);
},
/** @export */
SamplerParameteri: (sampler, pname, param) => {
  this.ctx.samplerParameteri(this.samplers[sampler], pname, param);
},
/** @export */
SamplerParameterf: (sampler, pname, param) => {
  this.ctx.samplerParameterf(this.samplers[sampler], pname, param);
},

/* Sync objects */
/** @export */
FenceSync: (condition, flags) => {
  let sync = this.ctx.fenceSync(condition, flags);
  let id = this.getNewId(this.syncs);
  sync.name = id;
  this.syncs[id] = sync;
  return id;
},
/** @export */
IsSync: (sync) => {
  return this.ctx.isSync(this.syncs[sync]);
},
/** @export */
DeleteSync: (id) => {
  let obj = this.syncs[id];
  if (obj && id != 0) {
    this.ctx.deleteSampler(obj);
    this.syncs[id] = null;
  }
},
/** @export */
ClientWaitSync: (sync, flags, timeout) => {
  return this.ctx.clientWaitSync(this.syncs[sync], flags, timeout);
},
/** @export */
WaitSync: (sync, flags, timeout) => {
  this.ctx.waitSync(this.syncs[sync], flags, timeout) ;
},


/* Transform Feedback */
/** @export */
CreateTransformFeedback: () => {
  let transformFeedback = this.ctx.createtransformFeedback();
  let id = this.getNewId(this.transformFeedbacks);
  transformFeedback.name = id;
  this.transformFeedbacks[id] = transformFeedback;
  return id;
},
/** @export */
DeleteTransformFeedback: (id)  => {
  let obj = this.transformFeedbacks[id];
  if (obj && id != 0) {
    this.ctx.deleteTransformFeedback(obj);
    this.transformFeedbacks[id] = null;
  }
},
/** @export */
IsTransformFeedback: (tf) => {
  return this.ctx.isTransformFeedback(this.transformFeedbacks[tf]);
},
/** @export */
BindTransformFeedback: (target, tf) => {
  this.ctx.bindTransformFeedback(target, this.transformFeedbacks[tf]);
},
/** @export */
BeginTransformFeedback: (primitiveMode) => {
  this.ctx.beginTransformFeedback(primitiveMode);
},
/** @export */
EndTransformFeedback: () => {
  this.ctx.endTransformFeedback();
},
/** @export */
TransformFeedbackVaryings: (program, varyings_ptr, varyings_len, bufferMode) => {
  const STRING_SIZE = 2*4;
  let varyings = [];
  for (let i = 0; i < varyings_len; i++) {
    let ptr = this.mem.loadPtr(varyings_ptr + i*STRING_SIZE + 0*4);
    let len = this.mem.loadPtr(varyings_ptr + i*STRING_SIZE + 1*4);
    varyings.push(this.mem.loadString(ptr, len));
  }
  this.ctx.transformFeedbackVaryings(this.programs[program], varyings, bufferMode);
},
/** @export */
PauseTransformFeedback: () => {
  this.ctx.pauseTransformFeedback();
},
/** @export */
ResumeTransformFeedback: () => {
  this.ctx.resumeTransformFeedback();
},


/* Uniform Buffer Objects and Transform Feedback Buffers */
/** @export */
BindBufferBase: (target, index, buffer) => {
  this.ctx.bindBufferBase(target, index, this.buffers[buffer]);
},
/** @export */
BindBufferRange: (target, index, buffer, offset, size) => {
  this.ctx.bindBufferRange(target, index, this.buffers[buffer], offset, size);
},
/** @export */
GetUniformBlockIndex: (program, uniformBlockName_ptr, uniformBlockName_len) => {
  return this.ctx.getUniformBlockIndex(this.programs[program], this.mem.loadString(uniformBlockName_ptr, uniformBlockName_len));
},
// any getActiveUniformBlockParameter(WebGLProgram program, GLuint uniformBlockIndex, GLenum pname);
/** @export */
GetActiveUniformBlockName: (program, uniformBlockIndex, buf_ptr, buf_len, length_ptr) => {
  let name = this.ctx.getActiveUniformBlockName(this.programs[program], uniformBlockIndex);

  let n = Math.min(buf_len, name.length);
  name = name.substring(0, n);
  this.mem.loadBytes(buf_ptr, buf_len).set(new TextEncoder("utf-8").encode(name))
  this.mem.storeInt(length_ptr, n);
},
/** @export */
UniformBlockBinding: (program, uniformBlockIndex, uniformBlockBinding) => {
  this.ctx.uniformBlockBinding(this.programs[program], uniformBlockIndex, uniformBlockBinding);
},

/* Vertex Array Objects */
/** @export */
CreateVertexArray: () => {
  let vao = this.ctx.createVertexArray();
  let id = this.getNewId(this.vaos);
  vao.name = id;
  this.vaos[id] = vao;
  return id;
},
/** @export */
DeleteVertexArray: (id) => {
  let obj = this.vaos[id];
  if (obj && id != 0) {
    this.ctx.deleteVertexArray(obj);
    this.vaos[id] = null;
  }
},
/** @export */
IsVertexArray: (vertexArray) => {
  return this.ctx.isVertexArray(this.vaos[vertexArray]);
},
/** @export */
BindVertexArray: (vertexArray) => {
  this.ctx.bindVertexArray(this.vaos[vertexArray]);
},
