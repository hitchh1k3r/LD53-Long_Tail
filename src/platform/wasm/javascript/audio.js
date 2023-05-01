/** @export */
init_audio: () => {
  window.all_audio = [];
  window.music = new Audio();
  window.music.loop = true;
},
/** @export */
make_sound: (filename_ptr, filename_len) => {
  var audio = new Audio(wasmMemoryInterface.loadString(filename_ptr, filename_len));
  window.all_audio.push(audio);
  return window.all_audio.length-1;
},
/** @export */
play_sound: (id) => {
  var sound = window.all_audio[id]
  sound.play();
  sound.currentTime = 0;
},
/** @export */
play_music: (filename_ptr, filename_len) => {
  if (filename_len == 0) {
    window.music.pause();
    window.music.currentTime = 0;
  } else {
    window.music.src = wasmMemoryInterface.loadString(filename_ptr, filename_len);
    window.music.play();
  }
},
