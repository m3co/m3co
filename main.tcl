
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

    set label $conf(frame).label
    set text [expr { $entr($conf(key)) != "" ? $entr($conf(key)) : "-" }]
    if { [winfo exists $label] == 0 } {
      pack [label $label] -side left
    }
    $label configure -text $text
    bind $label <1> "labelentry::'begin'redact %W {[array get conf]} \
      {[array get entr]}"
  }

  proc 'end'redact { {text ""} } {
    variable lastEdit
    if { $lastEdit(input) != "" } {
      if { [winfo exists $lastEdit(input)] == 1 } {
        destroy $lastEdit(input)
      }
    }
    if { $lastEdit(label) != "" } {
      if { [winfo exists $lastEdit(label)] == 1 } {
        pack $lastEdit(label) -side left
        if { $text != "" } {
          $lastEdit(label) configure -text $text
        }
      }
    }
    set lastEdit(input) ""
    set lastEdit(label) ""
  }

  proc update { el key e } {
    array set event [deserialize $e]
    if { [dict get $event(entry) $key] == [$el get] } {
      labelentry::'end'redact [$el get]
      return
    }
    set event(value) [$el get]

    chan puts $MAIN::chan [array get event] ;## OJO CON ESTE ERROR!
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
    set lastEdit(input) [entry $frame.input -width 0]
    $lastEdit(input) insert 0 $entr($key)
    bind $lastEdit(input) <Return> "labelentry::update %W $key {[array get event]}"
    pack forget $el
    pack $lastEdit(input) -fill x -expand true
    focus $lastEdit(input)
  }
}

namespace eval extendcombo {

  proc setup { path } {
    bind $path <KeyRelease> +[list extendcombo::show'listbox %W %K]
  }

  proc do'autocomplete {path key} {
    #
    # autocomplete a string in the ttk::combobox from the list of values
    #
    # Any key string with more than one character and is not entirely
    # lower-case is considered a function key and is thus ignored.
    #
    # path -> path to the combobox
    #
    if {[string length $key] > 1 && [string tolower $key] != $key} {return}
    set text [string map [list {[} {\[} {]} {\]}] [$path get]]
    if {[string equal $text ""]} {return}
    set values [$path cget -values]
    set x [lsearch $values $text*]
    if {$x < 0} {return}
    set index [$path index insert]
    $path set [lindex $values $x]
    $path icursor $index
    $path selection range insert end
  }

  proc show'listbox { path key } {
    ttk::combobox::Post $path
    update idletasks
    focus $path
    do'autocomplete $path $key
  }

}
