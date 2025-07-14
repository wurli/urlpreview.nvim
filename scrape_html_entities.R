library(rvest)
library(dplyr)
library(tidyr)
library(stringr)

wiki <- read_html("https://en.wikipedia.org/wiki/List_of_XML_and_HTML_character_entity_references")

entities_raw <- wiki |> 
  html_elements("table") |> 
  _[3] |> 
  html_table() |> 
  _[[1]]

entities <- entities_raw |> 
  select(
    entity = Entities,
    char = Char.,
    standard = Standard,
  ) |> 
  mutate(
    entity = str_remove_all(entity, r"(\[[a-z]\])"),
    char = char |> 
      str_replace_all(c(
        "ZWSP" = "\U200B",
        "TAB" = "\U0009",
        "LF" = "\n\n",
        "WJ" = "\U2060",
        "\\\\" = "\\",
        "\\(\\)" = "\U2061"
      ))
  ) |> 
  separate_longer_delim(entity, regex(r"(\s)")) |> 
  filter(
    str_detect(entity, "^&")
  )

code <- entities |> 
  glue::glue_data('    ["{entity}"] = [==[{char}]==]') |> 
  paste(collapse = ",\n") |> 
  paste0("return {\n", text = _, "\n}")

readr::write_file(code, "lua/urlpreview/html_entities.lua")
