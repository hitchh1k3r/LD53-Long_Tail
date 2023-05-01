package html_generators

import "core:os"

import "build:beard"

gen_html :: proc(title : string, javascript_path : string, output_path : string) {
  PROFILE_START("read_js()")
  javascript_file, _ := os.read_entire_file(javascript_path)
  PROFILE_END()
  defer delete(javascript_file)
  beard_data := beard.Map{
    "page_title" = title,
    "javascript" = string(javascript_file),
  }
  html_src := beard.process(TEMPLATE_HTML_FILE, beard_data)
  PROFILE_START("write_html()")
  os.write_entire_file(output_path, transmute([]u8)(html_src))
  PROFILE_END()
}

@(private="file")
TEMPLATE_HTML_FILE ::
`<!doctype html>` +
`<html>` +
  `<head>` +
    `<title>{{page_title}}</title>` +
    `<style>` +
      `*{margin:0;padding:0;}` +
      `html,body{width:100%;height:100%;overflow:hidden;background:#000;}` +
    `</style>` +
  `</head>` +
  `<body>` +
    `<script>{{javascript}}</script>` +
  `</body>` +
`</html>
`
