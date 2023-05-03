/** @export */
init_event_raw: (ep) => {
  const W = 4;
  let offset = ep;
  let off = (amount, alignment) => {
    if (alignment === undefined) {
      alignment = Math.min(amount, W);
    }
    if (offset % alignment != 0) {
      offset += alignment - (offset%alignment);
    }
    let x = offset;
    offset += amount;
    return x;
  };

  let wmi = wasmMemoryInterface;

  let e = event_temp_data.event;

  wmi.storeU32(off(4), event_temp_data.name_code);
  if (e.target == document) {
    wmi.storeU32(off(4), 1);
  } else if (e.target == window) {
    wmi.storeU32(off(4), 2);
  } else {
    wmi.storeU32(off(4), 0);
  }
  if (e.currentTarget == document) {
    wmi.storeU32(off(4), 1);
  } else if (e.currentTarget == window) {
    wmi.storeU32(off(4), 2);
  } else {
    wmi.storeU32(off(4), 0);
  }

  wmi.storeUint(off(W), event_temp_data.id_ptr);
  wmi.storeUint(off(W), event_temp_data.id_len);

  wmi.storeF64(off(8), e.timeStamp*1e-3);

  wmi.storeU8(off(1), e.eventPhase);
  let options = 0;
  if (!!e.bubbles)    { options |= 1<<0; }
  if (!!e.cancelable) { options |= 1<<1; }
  if (!!e.composed)   { options |= 1<<2; }
  wmi.storeU8(off(1), options);
  wmi.storeU8(off(1), !!e.isComposing);
  wmi.storeU8(off(1), !!e.isTrusted);

  let base = off(0, 8);
  off(W*2, W)
  if (e instanceof MouseEvent) {
    wmi.storeI64(off(8), e.screenX);
    wmi.storeI64(off(8), e.screenY);
    wmi.storeI64(off(8), e.clientX);
    wmi.storeI64(off(8), e.clientY);
    wmi.storeI64(off(8), e.offsetX);
    wmi.storeI64(off(8), e.offsetY);
    wmi.storeI64(off(8), e.pageX);
    wmi.storeI64(off(8), e.pageY);
    wmi.storeI64(off(8), e.movementX);
    wmi.storeI64(off(8), e.movementY);

    wmi.storeU8(off(1), !!e.ctrlKey);
    wmi.storeU8(off(1), !!e.shiftKey);
    wmi.storeU8(off(1), !!e.altKey);
    wmi.storeU8(off(1), !!e.metaKey);

    wmi.storeI16(off(2), e.button);
    wmi.storeU16(off(2), e.buttons);
  } else if (e instanceof KeyboardEvent) {
    let keyOffset = off(W*2, W);
    let codeOffset = off(W*2, W);
    wmi.storeU8(off(1), e.location);

    wmi.storeU8(off(1), !!e.ctrlKey);
    wmi.storeU8(off(1), !!e.shiftKey);
    wmi.storeU8(off(1), !!e.altKey);
    wmi.storeU8(off(1), !!e.metaKey);

    wmi.storeU8(off(1), !!e.repeat);

    let keyBuffer = off(16);
    let keyLen = Math.min(16, e.key.length);
    wmi.loadBytes(keyBuffer, keyLen).set(new TextEncoder("utf-8").encode(e.key))
    wmi.storeUint(keyOffset, keyBuffer);
    wmi.storeUint(keyOffset + W, keyLen);

    let codeBuffer = off(16);
    let codeLen = Math.min(16, e.code.length);
    wmi.loadBytes(codeBuffer, codeLen).set(new TextEncoder("utf-8").encode(e.code))
    wmi.storeUint(codeOffset, codeBuffer);
    wmi.storeUint(codeOffset + W, codeLen);
  } else if (e instanceof WheelEvent) {
    wmi.storeF64(off(8), e.deltaX);
    wmi.storeF64(off(8), e.deltaY);
    wmi.storeF64(off(8), e.deltaZ);
    wmi.storeU32(off(4), e.deltaMode);
  } else if (e instanceof Event) {
    if ('scrollX' in e) {
      wmi.storeF64(off(8), e.scrollX);
      wmi.storeF64(off(8), e.scrollY);
    }
  }
},

/** @export */
add_event_listener: (id_ptr, id_len, name_ptr, name_len, name_code, data, callback, use_capture) => {
  let id = wasmMemoryInterface.loadString(id_ptr, id_len);
  let name = wasmMemoryInterface.loadString(name_ptr, name_len);
  let element = getElement(id);
  if (element == undefined) {
    return false;
  }

  let listener = (e) => {
    const odin_ctx = wasmMemoryInterface.exports.default_context_ptr();
    event_temp_data.id_ptr = id_ptr;
    event_temp_data.id_len = id_len;
    event_temp_data.event = e;
    event_temp_data.name_code = name_code;
    wasmMemoryInterface.exports.odin_dom_do_event_callback(data, callback, odin_ctx);
  };
  wasmMemoryInterface.listenerMap[{data: data, callback: callback}] = listener;
  element.addEventListener(name, listener, !!use_capture);
  return true;
},

/** @export */
remove_event_listener: (id_ptr, id_len, name_ptr, name_len, data, callback) => {
  let id = wasmMemoryInterface.loadString(id_ptr, id_len);
  let name = wasmMemoryInterface.loadString(name_ptr, name_len);
  let element = getElement(id);
  if (element == undefined) {
    return false;
  }

  let listener = wasmMemoryInterface.listenerMap[{data: data, callback: callback}];
  if (listener == undefined) {
    return false;
  }
  element.removeEventListener(name, listener);
  return true;
},


/** @export */
add_window_event_listener: (name_ptr, name_len, name_code, data, callback, use_capture) => {
  let name = wasmMemoryInterface.loadString(name_ptr, name_len);
  let element = window;
  let listener = (e) => {
    const odin_ctx = wasmMemoryInterface.exports.default_context_ptr();
    event_temp_data.id_ptr = 0;
    event_temp_data.id_len = 0;
    event_temp_data.event = e;
    event_temp_data.name_code = name_code;
    wasmMemoryInterface.exports.odin_dom_do_event_callback(data, callback, odin_ctx);
  };
  wasmMemoryInterface.listenerMap[{data: data, callback: callback}] = listener;
  element.addEventListener(name, listener, !!use_capture);
  return true;
},

/** @export */
remove_window_event_listener: (name_ptr, name_len, data, callback) => {
  let name = wasmMemoryInterface.loadString(name_ptr, name_len);
  let element = window;
  let key = {data: data, callback: callback};
  let listener = wasmMemoryInterface.listenerMap[key];
  if (!listener) {
    return false;
  }
  wasmMemoryInterface.listenerMap[key] = undefined;

  element.removeEventListener(name, listener);
  return true;
},

/** @export */
event_stop_propagation: () => {
  if (event_temp_data && event_temp_data.event) {
    event_temp_data.event.eventStopPropagation();
  }
},
/** @export */
event_stop_immediate_propagation: () => {
  if (event_temp_data && event_temp_data.event) {
    event_temp_data.event.eventStopImmediatePropagation();
  }
},
/** @export */
event_prevent_default: () => {
  if (event_temp_data && event_temp_data.event) {
    event_temp_data.event.preventDefault();
  }
},

/** @export */
dispatch_custom_event: (id_ptr, id_len, name_ptr, name_len, options_bits) => {
  let id = wasmMemoryInterface.loadString(id_ptr, id_len);
  let name = wasmMemoryInterface.loadString(name_ptr, name_len);
  let options = {
    bubbles:   (options_bits & (1<<0)) !== 0,
    cancelabe: (options_bits & (1<<1)) !== 0,
    composed:  (options_bits & (1<<2)) !== 0,
  };

  let element = getElement(id);
  if (element) {
    element.dispatchEvent(new Event(name, options));
    return true;
  }
  return false;
},

/** @export */
get_element_value_f64: (id_ptr, id_len) => {
  let id = wasmMemoryInterface.loadString(id_ptr, id_len);
  let element = getElement(id);
  return element ? element.value : 0;
},
/** @export */
get_element_value_string: (id_ptr, id_len, buf_ptr, buf_len) => {
  let id = wasmMemoryInterface.loadString(id_ptr, id_len);
  let element = getElement(id);
  if (element) {
    let str = element.value;
    if (buf_len > 0 && buf_ptr) {
      let n = Math.min(buf_len, str.length);
      str = str.substring(0, n);
      this.mem.loadBytes(buf_ptr, buf_len).set(new TextEncoder("utf-8").encode(str))
      return n;
    }
  }
  return 0;
},
/** @export */
get_element_value_string_length: (id_ptr, id_len) => {
  let id = wasmMemoryInterface.loadString(id_ptr, id_len);
  let element = getElement(id);
  if (element) {
    return element.value.length;
  }
  return 0;
},
/** @export */
get_element_min_max: (ptr_array2_f64, id_ptr, id_len) => {
  let id = wasmMemoryInterface.loadString(id_ptr, id_len);
  let element = getElement(id);
  if (element) {
    let values = wasmMemoryInterface.loadF64Array(ptr_array2_f64, 2);
    values[0] = element.min;
    values[1] = element.max;
  }
},
/** @export */
set_element_value_f64: (id_ptr, id_len, value) => {
  let id = wasmMemoryInterface.loadString(id_ptr, id_len);
  let element = getElement(id);
  if (element) {
    element.value = value;
  }
},
/** @export */
set_element_value_string: (id_ptr, id_len, value_ptr, value_len) => {
  let id = wasmMemoryInterface.loadString(id_ptr, id_len);
  let value = wasmMemoryInterface.loadString(value_ptr, value_len);
  let element = getElement(id);
  if (element) {
    element.value = value;
  }
},

/** @export */
get_bounding_client_rect: (rect_ptr, id_ptr, id_len) => {
  let id = wasmMemoryInterface.loadString(id_ptr, id_len);
  let element = getElement(id);
  if (element) {
    let values = wasmMemoryInterface.loadF64Array(rect_ptr, 4);
    let rect = element.getBoundingClientRect();
    values[0] = rect.left;
    values[1] = rect.top;
    values[2] = rect.right  - rect.left;
    values[3] = rect.bottom - rect.top;
  }
},
/** @export */
window_get_rect: (rect_ptr) => {
  let values = wasmMemoryInterface.loadF64Array(rect_ptr, 4);
  values[0] = window.screenX;
  values[1] = window.screenY;
  values[2] = document.body.clientWidth;
  values[3] = document.body.clientHeight;
},

/** @export */
window_get_scroll: (pos_ptr) => {
  let values = wasmMemoryInterface.loadF64Array(pos_ptr, 2);
  values[0] = window.scrollX;
  values[1] = window.scrollY;
},
/** @export */
window_set_scroll: (x, y) => {
  window.scroll(x, y);
},

/** @export */
device_pixel_ratio: () => {
  return window.devicePixelRatio;
},
