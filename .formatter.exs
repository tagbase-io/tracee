# Used by "mix format"
[
  plugins: [MarkdownFormatter, Styler],
  markdown: [
    line_length: 80
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}", "README.md"]
]
