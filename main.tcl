
# Leer el TCL Style
# Escribir pruebas para este deserializador

# Convierte una string tipo CTA en un array
#
# PARAMS
# string - cadena a deserializar
#
# RETURN array
proc deserialize { string } {
  # Muestre como serializar el array
  array set result {}
  set key ""
  foreach step $string {
    if { $key == "" } {
      set key $step
    } else {
      set result($key) $step
      set key ""
    }
  }
  return [array get result]
}

namespace eval labelentry {
  array set lastEdit {
    label ""
    input ""
  }
  variable lastEdit

  proc setup { config entry } {
    array set entr [deserialize $entry]
    array set conf [deserialize $config]

    set label [label $conf(frame).label -text [expr { \
      $entr($conf(key)) != "" ? $entr($conf(key)) : "-" }]]
    bind $label <1> "labelentry::'begin'redact %W {[array get conf]} \
      {[array get entr]}"
    pack $label -side left
  }

  proc 'end'redact { {text ""} } {
    variable lastEdit
    if { $lastEdit(input) != "" } {
      destroy $lastEdit(input)
    }
    if { $lastEdit(label) != "" } {
      $lastEdit(label) configure -text $text
      pack $lastEdit(label) -side left
    }
    set lastEdit(input) ""
    set lastEdit(label) ""
  }

  proc update { el key e } {
    global chan
    array set event [deserialize $e]
    set event(value) [$el get]

    chan puts $chan [array get event]
    labelentry::'end'redact ...
  }

  proc 'begin'redact { el config entry } {
    variable lastEdit
    labelentry::'end'redact
    array set entr [deserialize $entry]
    array set conf [deserialize $config]

    set key $conf(key)
    set frame $conf(frame)

    array set event {
      query update
    }
    set event(from) $conf(from)
    set event(module) $conf(module)

    set event(idkey) $conf(idkey)
    set event(key) $key
    set event(id) $entr($conf(idkey))
    set event(entry) $entry

    set lastEdit(label) $el
    set lastEdit(input) [entry $frame.input]
    $lastEdit(input) insert 0 $entr($key)
    bind $lastEdit(input) <FocusOut> "labelentry::'end'redact $entr($key)"
    bind $lastEdit(input) <Return> "labelentry::update %W $key {[array get event]}"
    pack forget $el
    pack $lastEdit(input) -fill x -expand true
  }
}
