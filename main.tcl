
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

proc lremove {listVariable value} {
  upvar 1 $listVariable var
  set idx [lsearch -exact $var $value]
  set var [lreplace $var $idx $idx]
}

namespace eval labelentry {
  array set lastEdit {
    label ""
    input ""
  }
  variable lastEdit

  # Configura el labelentry
  # A modo de ejemplo se expone "config"
  #
  #  array set conf [list \
  #    from Preliminars \
  #    module Preliminars \
  #    idkey id \
  #    key $param \
  #    frame $base.$param.$id \ # setup se encarga de crear ese $frame.label
  #    currency false \
  #    dollar false
  #  ]
  #
  # row es la linea a redactar y por lo general se escribe como $response(row)
  proc setup { config row } {
    array set entr [deserialize $row]
    array set conf [deserialize $config]

    set label $conf(frame).label
    set text [expr { ($entr($conf(key)) != "" && $entr($conf(key)) != "null") ? \
      [array get conf currency] == "currency true" ? \
      "[expr { [array get conf dollar] == "dollar true" ? \
      "\$" : "" }][format'currency $entr($conf(key))]" : \
      $entr($conf(key)) : "-" }]
    if { [winfo exists $label] == 0 } {
      pack [label $label] -side [expr { \
        [array get conf currency] == "currency true" ? "right" : "left" }]
    }
    $label configure -text $text
    bind $label <1> [list labelentry::'begin'redact %W [array get conf] \
      [array get entr]]
  }

  proc 'end'redact { c {text ""} } {
    variable lastEdit
    array set config [deserialize $c]
    if { $lastEdit(input) != "" } {
      if { [winfo exists $lastEdit(input)] == 1 } {
        destroy $lastEdit(input)
      }
    }
    if { $lastEdit(label) != "" } {
      if { [winfo exists $lastEdit(label)] == 1 } {
        if { [array get config currency] == "currency true" } {
          pack $lastEdit(label) -side right
        } else {
          pack $lastEdit(label) -side left
        }
        if { $text != "" } {
          $lastEdit(label) configure -text $text
        }
      }
    }
    set lastEdit(input) ""
    set lastEdit(label) ""
  }

  proc update { el key e c } {
    array set event [deserialize $e]
    if { [dict get $event(row) $key] == [$el get] } {
      labelentry::'end'redact $c [$el get]
      return
    }
    set event(value) [$el get]

    chan puts $MAIN::chan [array get event] ;## OJO CON ESTE ERROR!
    labelentry::'end'redact $c ...
  }

  proc 'begin'redact { el config row } {
    variable lastEdit
    labelentry::'end'redact $config
    array set entr [deserialize $row]
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
    set event(row) $row

    set lastEdit(label) $el
    set lastEdit(input) [entry $frame.input -width 0]
    $lastEdit(input) insert 0 [expr { $entr($key) == "null" ? "" : $entr($key) }]
    bind $lastEdit(input) <Return> [list labelentry::update %W $key \
      [array get event] [array get conf]]
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

proc format'currency {num {sep ,}} {
  if { $num == "" } return
  if { $num == "null" } return
  # Find the whole number and decimal (if any)
  set whole [expr int($num)]
  set decimal [expr $num - int($num)]

  #Basically convert decimal to a string
  set decimal [format %0.2f $decimal]

  # If number happens to be a negative, shift over the range positions
  # when we pick up the decimal string part we want to keep
  if { $decimal <=0 } {
      set decimal [string range $decimal 2 4]
  } else {
      set decimal [string range $decimal 1 3]
  }

  # If $decimal is zero, then assign the default value of .00
  # and glue the formatted $decimal to the whole number ($whole)
  if { $decimal == 0} {
      set num $whole; #.00
  } else {
      #set num $whole$decimal
  }

  # Take given number and insert commas every 3 positions
  while {[regsub {^([-+]?\d+)(\d\d\d)} $num "\\1$sep\\2" num]} {}

  # Were done; give the result back
  return $num
}

proc connect { ns } {
  namespace eval $ns {
   #set chan [socket {x12.m3c.space} 12345]
    set chan [socket localhost       12345]

    chan configure $chan -encoding utf-8 -blocking 0 -buffering line
    chan event $chan readable "[namespace current]::handle'event"

    proc handle'event { } {
      variable chan
      chan gets $chan data
      if { $data == "" } {
        return
      }
      array set response [deserialize $data]
      #puts "\nresponse:"
      #parray response
      if { [$response(module)::'do'$response(query) response] == "await-next" } {
        chan configure $chan -encoding utf-8 -blocking 1 \
          -buffering full -translation binary
        $response(module)::'do'$response(query)'next [chan read -nonewline $chan]
        chan configure $chan -encoding utf-8 -blocking 0 \
          -buffering line -translation auto
      }
    }
  }
}

proc howmanymonths { d1 d2 } {
  set c $d1
  set i 1
  while { $c < $d2 } {
    set c [clock add $c 1 months]
    incr i
  }
  return $i
}
