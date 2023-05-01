/** @export */
SetCurrentContextById: (name_ptr, name_len) => {
  let name = this.mem.loadString(name_ptr, name_len);
  let element = getElement(name);
  return this.setCurrentContext(element, {alpha: true, antialias: true, depth: true, premultipliedAlpha: true});
},
/** @export */
CreateCurrentContextById: (name_ptr, name_len, attributes) => {
  let name = this.mem.loadString(name_ptr, name_len);
  let element = getElement(name);

  let contextSettings = {
    alpha:                        !(attributes & (1<<0)),
    antialias:                    !(attributes & (1<<1)),
    depth:                        !(attributes & (1<<2)),
    failIfMajorPerformanceCaveat: !!(attributes & (1<<3)),
    premultipliedAlpha:           !(attributes & (1<<4)),
    preserveDrawingBuffer:        !!(attributes & (1<<5)),
    stencil:                      !!(attributes & (1<<6)),
    desynchronized:               !!(attributes & (1<<7)),
  };

  return this.setCurrentContext(element, contextSettings);
},
/** @export */
GetCurrentContextAttributes: () => {
  if (!this.ctx) {
    return 0;
  }
  let attrs = this.ctx.getContextAttributes();
  let res = 0;
  if (!attrs.alpha)                        res |= 1<<0;
  if (!attrs.antialias)                    res |= 1<<1;
  if (!attrs.depth)                        res |= 1<<2;
  if (attrs.failIfMajorPerformanceCaveat)  res |= 1<<3;
  if (!attrs.premultipliedAlpha)           res |= 1<<4;
  if (attrs.preserveDrawingBuffer)         res |= 1<<5;
  if (attrs.stencil)                       res |= 1<<6;
  if (attrs.desynchronized)                res |= 1<<7;
  return res;
},

/** @export */
DrawingBufferWidth:  () => this.ctx.drawingBufferWidth,
/** @export */
DrawingBufferHeight: () => this.ctx.drawingBufferHeight,

/** @export */
IsExtensionSupported: (name_ptr, name_len) => {
  let name = this.mem.loadString(name_ptr, name_len);
  let extensions = this.ctx.getSupportedExtensions();
  return extensions.indexOf(name) !== -1
},


/** @export */
GetError: () => {
  let err = this.lastError;
  this.recordError(0);
  if (err) {
    return err;
  }
  return this.ctx.getError();
},

/** @export */
GetWebGLVersion: (major_ptr, minor_ptr) => {
  let version = this.ctx.getParameter(0x1F02);
  if (version.indexOf("WebGL 2.0") !== -1) {
    this.mem.storeI32(major_ptr, 2);
    this.mem.storeI32(minor_ptr, 0);
    return;
  }

  this.mem.storeI32(major_ptr, 1);
  this.mem.storeI32(minor_ptr, 0);
},
/** @export */
GetESVersion: (major_ptr, minor_ptr) => {
  let version = this.ctx.getParameter(0x1F02);
  if (version.indexOf("OpenGL ES 3.0") !== -1) {
    this.mem.storeI32(major_ptr, 3);
    this.mem.storeI32(minor_ptr, 0);
    return;
  }

  this.mem.storeI32(major_ptr, 2);
  this.mem.storeI32(minor_ptr, 0);
},


/** @export */
ActiveTexture: (x) => {
  this.ctx.activeTexture(x);
},
/** @export */
AttachShader: (program, shader) => {
  this.ctx.attachShader(this.programs[program], this.shaders[shader]);
},
/** @export */
BindAttribLocation: (program, index, name_ptr, name_len) => {
  let name = this.mem.loadString(name_ptr, name_len);
  this.ctx.bindAttribLocation(this.programs[program], index, name)
},
/** @export */
BindBuffer: (target, buffer) => {
  let bufferObj = buffer ? this.buffers[buffer] : null;
  if (target == 35051) {
    this.ctx.currentPixelPackBufferBinding = buffer;
  } else {
    if (target == 35052) {
      this.ctx.currentPixelUnpackBufferBinding = buffer;
    }
    this.ctx.bindBuffer(target, bufferObj)
  }
},
/** @export */
BindFramebuffer: (target, buffer) => {
  // TODO: BindFramebuffer
},
/** @export */
BindTexture: (target, texture) => {
  this.ctx.bindTexture(target, texture ? this.textures[texture] : null)
},
/** @export */
BlendColor: (red, green, blue, alpha) => {
  this.ctx.blendColor(red, green, blue, alpha);
},
/** @export */
BlendEquation: (mode) => {
  this.ctx.blendEquation(mode);
},
/** @export */
BlendFunc: (sfactor, dfactor) => {
  this.ctx.blendFunc(sfactor, dfactor);
},
/** @export */
BlendFuncSeparate: (srcRGB, dstRGB, srcAlpha, dstAlpha) => {
  this.ctx.blendFuncSeparate(srcRGB, dstRGB, srcAlpha, dstAlpha);
},


/** @export */
BufferData: (target, size, data, usage) => {
  if (data) {
    this.ctx.bufferData(target, this.mem.loadBytes(data, size), usage);
  } else {
    this.ctx.bufferData(target, size, usage);
  }
},
/** @export */
BufferSubData: (target, offset, size, data) => {
  if (data) {
    this.ctx.bufferSubData(target, offset, this.mem.loadBytes(data, size));
  } else {
    this.ctx.bufferSubData(target, offset, null);
  }
},


/** @export */
Clear: (x) => {
  this.ctx.clear(x);
},
/** @export */
ClearColor: (r, g, b, a) => {
  this.ctx.clearColor(r, g, b, a);
},
/** @export */
ClearDepth: (x) => {
  this.ctx.clearDepth(x);
},
/** @export */
ClearStencil: (x) => {
  this.ctx.clearStencil(x);
},
/** @export */
ColorMask: (r, g, b, a) => {
  this.ctx.colorMask(!!r, !!g, !!b, !!a);
},
/** @export */
CompileShader: (shader) => {
  this.ctx.compileShader(this.shaders[shader]);
},


/** @export */
CompressedTexImage2D: (target, level, internalformat, width, height, border, imageSize, data) => {
  if (data) {
    this.ctx.compressedTexImage2D(target, level, internalformat, width, height, border, this.mem.loadBytes(data, imageSize));
  } else {
    this.ctx.compressedTexImage2D(target, level, internalformat, width, height, border, null);
  }
},
/** @export */
CompressedTexSubImage2D: (target, level, xoffset, yoffset, width, height, format, imageSize, data) => {
  if (data) {
    this.ctx.compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, this.mem.loadBytes(data, imageSize));
  } else {
    this.ctx.compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, null);
  }
},

/** @export */
CopyTexImage2D: (target, level, internalformat, x, y, width, height, border) => {
  this.ctx.copyTexImage2D(target, level, internalformat, x, y, width, height, border);
},
/** @export */
CopyTexSubImage2D: (target, level, xoffset, yoffset, x, y, width, height) => {
  this.ctx.copyTexImage2D(target, level, xoffset, yoffset, x, y, width, height);
},


/** @export */
CreateBuffer: () => {
  let buffer = this.ctx.createBuffer();
  if (!buffer) {
    this.recordError(1282);
    return 0;
  }
  let id = this.getNewId(this.buffers);
  buffer.name = id
  this.buffers[id] = buffer;
  return id;
},
/** @export */
CreateFramebuffer: () => {
  let buffer = this.ctx.createFramebuffer();
  let id = this.getNewId(this.framebuffers);
  buffer.name = id
  this.framebuffers[id] = buffer;
  return id;
},
/** @export */
CreateProgram: () => {
  let program = this.ctx.createProgram();
  let id = this.getNewId(this.programs);
  program.name = id;
  this.programs[id] = program;
  return id;
},
/** @export */
CreateRenderbuffer: () => {
  let buffer = this.ctx.createRenderbuffer();
  let id = this.getNewId(this.renderbuffers);
  buffer.name = id;
  this.renderbuffers[id] = buffer;
  return id;
},
/** @export */
CreateShader: (shaderType) => {
  let shader = this.ctx.createShader(shaderType);
  let id = this.getNewId(this.shaders);
  shader.name = id;
  this.shaders[id] = shader;
  return id;
},
/** @export */
CreateTexture: () => {
  let texture = this.ctx.createTexture();
  if (!texture) {
    this.recordError(1282)
    return 0;
  }
  let id = this.getNewId(this.textures);
  texture.name = id;
  this.textures[id] = texture;
  return id;
},


/** @export */
CullFace: (mode) => {
  this.ctx.cullFace(mode);
},


/** @export */
DeleteBuffer: (id) => {
  let obj = this.buffers[id];
  if (obj && id != 0) {
    this.ctx.deleteBuffer(obj);
    this.buffers[id] = null;
  }
},
/** @export */
DeleteFramebuffer: (id) => {
  let obj = this.framebuffers[id];
  if (obj && id != 0) {
    this.ctx.deleteFramebuffer(obj);
    this.framebuffers[id] = null;
  }
},
/** @export */
DeleteProgram: (id) => {
  let obj = this.programs[id];
  if (obj && id != 0) {
    this.ctx.deleteProgram(obj);
    this.programs[id] = null;
  }
},
/** @export */
DeleteRenderbuffer: (id) => {
  let obj = this.renderbuffers[id];
  if (obj && id != 0) {
    this.ctx.deleteRenderbuffer(obj);
    this.renderbuffers[id] = null;
  }
},
/** @export */
DeleteShader: (id) => {
  let obj = this.shaders[id];
  if (obj && id != 0) {
    this.ctx.deleteShader(obj);
    this.shaders[id] = null;
  }
},
/** @export */
DeleteTexture: (id) => {
  let obj = this.textures[id];
  if (obj && id != 0) {
    this.ctx.deleteTexture(obj);
    this.textures[id] = null;
  }
},


/** @export */
DepthFunc: (func) => {
  this.ctx.depthFunc(func);
},
/** @export */
DepthMask: (flag) => {
  this.ctx.depthMask(!!flag);
},
/** @export */
DepthRange: (zNear, zFar) => {
  this.ctx.depthRange(zNear, zFar);
},
/** @export */
DetachShader: (program, shader) => {
  this.ctx.detachShader(this.programs[program], this.shaders[shader]);
},
/** @export */
Disable: (cap) => {
  this.ctx.disable(cap);
},
/** @export */
DisableVertexAttribArray: (index) => {
  this.ctx.disableVertexAttribArray(index);
},
/** @export */
DrawArrays: (mode, first, count) => {
  this.ctx.drawArrays(mode, first, count);
},
/** @export */
DrawElements: (mode, count, type, indices) => {
  this.ctx.drawElements(mode, count, type, indices);
},


/** @export */
Enable: (cap) => {
  this.ctx.enable(cap);
},
/** @export */
EnableVertexAttribArray: (index) => {
  this.ctx.enableVertexAttribArray(index);
},
/** @export */
Finish: () => {
  this.ctx.finish();
},
/** @export */
Flush: () => {
  this.ctx.flush();
},
/** @export */
FramebufferRenderBuffer: (target, attachment, renderbuffertarget, renderbuffer) => {
  this.ctx.framebufferRenderBuffer(target, attachment, renderbuffertarget, this.renderbuffers[renderbuffer]);
},
/** @export */
FramebufferTexture2D: (target, attachment, textarget, texture, level) => {
  this.ctx.framebufferTexture2D(target, attachment, textarget, this.textures[texture], level);
},
/** @export */
FrontFace: (mode) => {
  this.ctx.frontFace(mode);
},


/** @export */
GenerateMipmap: (target) => {
  this.ctx.generateMipmap(target);
},


/** @export */
GetAttribLocation: (program, name_ptr, name_len) => {
  let name = this.mem.loadString(name_ptr, name_len);
  return this.ctx.getAttribLocation(this.programs[program], name);
},



/** @export */
GetProgramParameter: (program, pname) => {
  return this.ctx.getProgramParameter(this.programs[program], pname)
},
/** @export */
GetProgramInfoLog: (program, buf_ptr, buf_len, length_ptr) => {
  let log = this.ctx.getProgramInfoLog(this.programs[program]);
  if (log === null) {
    log = "(unknown error)";
  }
  if (buf_len > 0 && buf_ptr) {
    let n = Math.min(buf_len, log.length);
    log = log.substring(0, n);
    this.mem.loadBytes(buf_ptr, buf_len).set(new TextEncoder("utf-8").encode(log))

    this.mem.storeInt(length_ptr, n);
  }
},
/** @export */
GetShaderInfoLog: (shader, buf_ptr, buf_len, length_ptr) => {
  let log = this.ctx.getShaderInfoLog(this.shaders[shader]);
  if (log === null) {
    log = "(unknown error)";
  }
  if (buf_len > 0 && buf_ptr) {
    let n = Math.min(buf_len, log.length);
    log = log.substring(0, n);
    this.mem.loadBytes(buf_ptr, buf_len).set(new TextEncoder("utf-8").encode(log))

    this.mem.storeInt(length_ptr, n);
  }
},
/** @export */
GetShaderiv: (shader, pname, p) => {
  if (p) {
    if (pname == 35716) {
      let log = this.ctx.getShaderInfoLog(this.shaders[shader]);
      if (log === null) {
        log = "(unknown error)";
      }
      this.mem.storeInt(p, log.length+1);
    } else if (pname == 35720) {
      let source = this.ctx.getShaderSource(this.shaders[shader]);
      let sourceLength = (source === null || source.length == 0) ? 0 : source.length+1;
      this.mem.storeInt(p, sourceLength);
    } else {
      let param = this.ctx.getShaderParameter(this.shaders[shader], pname);
      this.mem.storeI32(p, param);
    }
  } else {
    this.recordError(1281);
  }
},


/** @export */
GetUniformLocation: (program, name_ptr, name_len) => {
  let name = this.mem.loadString(name_ptr, name_len);
  let arrayOffset = 0;
  if (name.indexOf("]", name.length - 1) !== -1) {
    let ls = name.lastIndexOf("["),
    arrayIndex = name.slice(ls + 1, -1);
    if (arrayIndex.length > 0 && (arrayOffset = parseInt(arrayIndex,10)) < 0) {
      return -1;
    }
    name = name.slice(0, ls)
  }
  var ptable = this.programInfos[program];
  if (!ptable) {
    return -1;
  }
  var uniformInfo = ptable.uniforms[name];
  return (uniformInfo && arrayOffset < uniformInfo[0]) ? uniformInfo[1] + arrayOffset : -1
},


/** @export */
GetVertexAttribOffset: (index, pname) => {
  return this.ctx.getVertexAttribOffset(index, pname);
},


/** @export */
Hint: (target, mode) => {
  this.ctx.hint(target, mode);
},


/** @export */
IsBuffer:       (buffer)       => this.ctx.isBuffer(this.buffers[buffer]),
/** @export */
IsFramebuffer:  (framebuffer)  => this.ctx.isFramebuffer(this.framebuffers[framebuffer]),
/** @export */
IsProgram:      (program)      => this.ctx.isProgram(this.programs[program]),
/** @export */
IsRenderbuffer: (renderbuffer) => this.ctx.isRenderbuffer(this.renderbuffers[renderbuffer]),
/** @export */
IsShader:       (shader)       => this.ctx.isShader(this.shaders[shader]),
/** @export */
IsTexture:      (texture)      => this.ctx.isTexture(this.textures[texture]),

/** @export */
LineWidth: (width) => {
  this.ctx.lineWidth(width);
},
/** @export */
LinkProgram: (program) => {
  this.ctx.linkProgram(this.programs[program]);
  this.programInfos[program] = null;
  this.populateUniformTable(program);
},
/** @export */
PixelStorei: (pname, param) => {
  this.ctx.pixelStorei(pname, param);
},
/** @export */
PolygonOffset: (factor, units) => {
  this.ctx.polygonOffset(factor, units);
},


/** @export */
ReadnPixels: (x, y, width, height, format, type, bufSize, data) => {
  this.ctx.readPixels(x, y, width, format, type, this.mem.loadBytes(data, bufSize));
},
/** @export */
RenderbufferStorage: (target, internalformat, width, height) => {
  this.ctx.renderbufferStorage(target, internalformat, width, height);
},
/** @export */
SampleCoverage: (value, invert) => {
  this.ctx.sampleCoverage(value, !!invert);
},
/** @export */
Scissor: (x, y, width, height) => {
  this.ctx.scissor(x, y, width, height);
},
/** @export */
ShaderSource: (shader, strings_ptr, strings_length) => {
  let source = this.getSource(shader, strings_ptr, strings_length);
  this.ctx.shaderSource(this.shaders[shader], source);
},

/** @export */
StencilFunc: (func, ref, mask) => {
  this.ctx.stencilFunc(func, ref, mask);
},
/** @export */
StencilFuncSeparate: (face, func, ref, mask) => {
  this.ctx.stencilFuncSeparate(face, func, ref, mask);
},
/** @export */
StencilMask: (mask) => {
  this.ctx.stencilMask(mask);
},
/** @export */
StencilMaskSeparate: (face, mask) => {
  this.ctx.stencilMaskSeparate(face, mask);
},
/** @export */
StencilOp: (fail, zfail, zpass) => {
  this.ctx.stencilOp(fail, zfail, zpass);
},
/** @export */
StencilOpSeparate: (face, fail, zfail, zpass) => {
  this.ctx.stencilOpSeparate(face, fail, zfail, zpass);
},


/** @export */
TexImage2D: (target, level, internalformat, width, height, border, format, type, size, data) => {
  if (data) {
    switch (type) {
      case this.ctx.UNSIGNED_SHORT_5_6_5:
      case this.ctx.UNSIGNED_SHORT_4_4_4_4:
      case this.ctx.UNSIGNED_SHORT_5_5_5_1:
      case this.ctx.UNSIGNED_SHORT:
      case this.ctx.HALF_FLOAT_OES:
        this.ctx.texImage2D(target, level, internalformat, width, height, border, format, type, new Uint16Array(this.mem.memory.buffer, data, size / Uint16Array.BYTES_PER_ELEMENT));
        break;

      case this.ctx.UNSIGNED_INT:
      case this.ctx.UNSIGNED_INT_24_8_WEBGL:
        this.ctx.texImage2D(target, level, internalformat, width, height, border, format, type, new Uint32Array(this.mem.memory.buffer, data, size / Uint32Array.BYTES_PER_ELEMENT));
        break;

      case this.ctx.FLOAT:
        this.ctx.texImage2D(target, level, internalformat, width, height, border, format, type, new Float32Array(this.mem.memory.buffer, data, size / Float32Array.BYTES_PER_ELEMENT));
        break;

      case this.ctx.UNSIGNED_BYTE:
      default:
        this.ctx.texImage2D(target, level, internalformat, width, height, border, format, type, new Uint8Array(this.mem.memory.buffer, data, size / Uint8Array.BYTES_PER_ELEMENT));
        break;
    }
  } else {
    this.ctx.texImage2D(target, level, internalformat, width, height, border, format, type, null);
  }
},
/** @export */
TexParameterf: (target, pname, param) => {
  this.ctx.texParameterf(target, pname, param);
},
/** @export */
TexParameteri: (target, pname, param) => {
  this.ctx.texParameteri(target, pname, param);
},
/** @export */
TexSubImage2D: (target, level, xoffset, yoffset, width, height, format, type, size, data) => {
  this.ctx.texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, this.mem.loadBytes(data, size));
},


/** @export */
Uniform1f: (location, v0)             => { this.ctx.uniform1f(this.uniforms[location], v0);             },
/** @export */
Uniform2f: (location, v0, v1)         => { this.ctx.uniform2f(this.uniforms[location], v0, v1);         },
/** @export */
Uniform3f: (location, v0, v1, v2)     => { this.ctx.uniform3f(this.uniforms[location], v0, v1, v2);     },
/** @export */
Uniform4f: (location, v0, v1, v2, v3) => { this.ctx.uniform4f(this.uniforms[location], v0, v1, v2, v3); },

/** @export */
Uniform1i: (location, v0)             => { this.ctx.uniform1i(this.uniforms[location], v0);             },
/** @export */
Uniform2i: (location, v0, v1)         => { this.ctx.uniform2i(this.uniforms[location], v0, v1);         },
/** @export */
Uniform3i: (location, v0, v1, v2)     => { this.ctx.uniform3i(this.uniforms[location], v0, v1, v2);     },
/** @export */
Uniform4i: (location, v0, v1, v2, v3) => { this.ctx.uniform4i(this.uniforms[location], v0, v1, v2, v3); },

/** @export */
UniformMatrix2fv: (location, addr) => {
  let array = this.mem.loadF32Array(addr, 2*2);
  this.ctx.uniformMatrix2fv(this.uniforms[location], false, array);
},
/** @export */
UniformMatrix3fv: (location, addr) => {
  let array = this.mem.loadF32Array(addr, 3*3);
  this.ctx.uniformMatrix3fv(this.uniforms[location], false, array);
},
/** @export */
UniformMatrix4fv: (location, addr) => {
  let array = this.mem.loadF32Array(addr, 4*4);
  this.ctx.uniformMatrix4fv(this.uniforms[location], false, array);
},

/** @export */
UseProgram: (program) => {
  if (program) this.ctx.useProgram(this.programs[program]);
},
/** @export */
ValidateProgram: (program) => {
  if (program) this.ctx.validateProgram(this.programs[program]);
},


/** @export */
VertexAttrib1f: (index, x) => {
  this.ctx.vertexAttrib1f(index, x);
},
/** @export */
VertexAttrib2f: (index, x, y) => {
  this.ctx.vertexAttrib2f(index, x, y);
},
/** @export */
VertexAttrib3f: (index, x, y, z) => {
  this.ctx.vertexAttrib3f(index, x, y, z);
},
/** @export */
VertexAttrib4f: (index, x, y, z, w) => {
  this.ctx.vertexAttrib4f(index, x, y, z, w);
},
/** @export */
VertexAttribPointer: (index, size, type, normalized, stride, ptr) => {
  this.ctx.vertexAttribPointer(index, size, type, !!normalized, stride, ptr);
},

/** @export */
Viewport: (x, y, w, h) => {
  this.ctx.viewport(x, y, w, h);
},
