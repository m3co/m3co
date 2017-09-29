
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

  proc 'begin'redact { el frame key e } {
    variable lastEdit
    labelentry::'end'redact
    array set entry [deserialize $e]

    array set event {
      query update
      from Supplies
      module Supplies
    }

    set event(key) $key
    set event(idkey) Supplies.id
    set event(id) $entry(Supplies.id)

    set lastEdit(label) $el
    set lastEdit(input) [entry $frame.input]
    $lastEdit(input) insert 0 $entry($key)
    bind $lastEdit(input) <FocusOut> "labelentry::'end'redact $entry($key)"
    bind $lastEdit(input) <Return> "labelentry::update %W $key {[array get event]}"
    pack forget $el
    pack $lastEdit(input) -fill x -expand true
  }
}
