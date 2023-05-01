/** @export */
memory : memory,

/** @export */
data_end: () => {
    return wasmMemoryInterface.exports.__data_end;
},

/** @export */
heap_base: () => {
    return wasmMemoryInterface.exports.__heap_base;
},
