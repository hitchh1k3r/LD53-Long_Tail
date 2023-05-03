/** @export */
init_audio: () => {
  window.all_audio = { idx: 0 };
  window.wmi = wasmMemoryInterface;
},
/** @export */
make_sound: (data_ptr, data_len, is_looping) => {
  let blob = new Blob([wasmMemoryInterface.loadBytes(data_ptr, data_len)], { type: 'audio/mp3' });
  let url = window.URL.createObjectURL(blob);
  let audio = new Audio();
  audio.loop = is_looping;
  audio.src = url;
  audio.load();
  window.all_audio[window.all_audio.idx] = { audio: audio, url: url };
  window.all_audio.idx += 1;
  return window.all_audio.idx-1;
},
/** @export */
play_sound: (id) => {
  let sound = window.all_audio[id];
  sound.audio.currentTime = 0;
  sound.audio.play();
},
/** @export */
stop_sound: (id) => {
  let sound = window.all_audio[id];
  sound.audio.pause();
  sound.audio.stop();
},
/** @export */
free_sound: (id) => {
  let sound = window.all_audio[id];
  sound.audio.src = "";
  URL.revokeObjectURL(sound.url);
  window.all_audio[id] = null;
},
