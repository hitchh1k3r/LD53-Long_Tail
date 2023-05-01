/** @export */
write: (fd, ptr, len) => {
  const str = wasmMemoryInterface.loadString(ptr, len);
  if (fd == 1) {
    writeToConsole(str, false);
    return;
  } else if (fd == 2) {
    writeToConsole(str, true);
    return;
  } else {
    throw new Error("Invalid fd to 'write'" + str);
  }
},
/** @export */
trap: () => { throw new Error() },
/** @export */
alert: (ptr, len) => { alert(wasmMemoryInterface.loadString(ptr, len)) },
/** @export */
abort: () => { wasmMemoryInterface.abort() },
/** @export */
evaluate: (str_ptr, str_len) => { eval.call(null, wasmMemoryInterface.loadString(str_ptr, str_len)); },

/** @export */
time_now: () => {
  // convert ms to ns
  return Date.now() * 1e6;
},
/** @export */
tick_now: () => {
  // convert ms to ns
  return performance.now() * 1e6;
},

/** @export */
sqrt:    (x) => Math.sqrt(x),
/** @export */
sin:     (x) => Math.sin(x),
/** @export */
cos:     (x) => Math.cos(x),
/** @export */
pow:     (x, power) => Math.pow(x, power),
/** @export */
fmuladd: (x, y, z) => x*y + z,
/** @export */
ln:      (x) => Math.log(x),
/** @export */
exp:     (x) => Math.exp(x),
