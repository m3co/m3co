
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
  proc setup { config row descr } {
    array set entr [deserialize $row]
    array set conf [deserialize $config]
    array set description [deserialize $descr]

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
      [array get entr] [array get description]]
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

  proc update { el key e c descr } {
    array set description [deserialize $descr]
    array set event [deserialize $e]
    array set row [deserialize $event(row)]
    if { $row($key) == [$el get] } {
      labelentry::'end'redact $c [$el get]
      return
    }
    set id_to_json $event(id)
    if { [dict get $description($event(idkey)) jsontype] == "string" } {
      set id_to_json [json::write string $event(id)]
    }
    set event(value) [$el get]
    if { [dict get $description($event(key)) jsontype] == "string" } {
      set event(value) [json::write string [$el get]]
    }

    chan puts $MAIN::chan [json::write object \
      module [json::write string $event(module)] \
      query [json::write string $event(query)] \
      idkey [json::write string $event(idkey)] \
      key [json::write array [json::write string $event(key)]] \
      id $id_to_json \
      value [json::write array $event(value)] \
    ] ;# OJO CON ESTE ERROR, pues $MAIN::chan es una variable hard-coded

    labelentry::'end'redact $c ...
  }

  proc 'begin'redact { el config row description } {
    variable lastEdit
    labelentry::'end'redact $config
    array set entr [deserialize $row]
    array set conf [deserialize $config]
    array set descr [deserialize $description]

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
      [array get event] [array get conf] [array get descr]]
    pack forget $el
    pack $lastEdit(input) -fill x -expand true
    focus $lastEdit(input)
  }
}

namespace eval extendcombo {

  proc setup { path } {
    ##bind $path <KeyRelease> +[list extendcombo::show'listbox %W %K]
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
    ##focus $path
    ##do'autocomplete $path $key
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

set myserver {localhost}
package require json
proc connect { ns } {
  namespace eval $ns {
    global myserver
    set chan [socket -async $myserver 12345]
    set lasttime [clock seconds]

    chan configure $chan -encoding utf-8 -blocking 0 -buffering line
    chan event $chan readable "[namespace current]::handle'event"

    set flagempty 0
    proc handle'event { } {
      variable flagempty
      variable chan
      variable lasttime [clock seconds]
      set res -1
      set data ""
      catch { set res [chan gets $chan data] }
      if { $res == -1 } {
        if { $flagempty == 1 } {
          chan event $chan readable {}
          chan close $chan
          return
        }
        if { $data == "" } {
          set flagempty 1
          return
        }
      }
      set flagempty 0
      if { $data == "" } {
        update idletasks
        return
      }
      array set response [deserialize [json::json2dict $data]]
      if [info exists response(action)] {
        if { $response(action) == "check-conn" } {
          chan puts $chan ""
          return
        }
      }
      #puts "\nresponse:"
      #parray response
      $response(module)::'do'$response(query) response
    }

    proc reconnect { } {
      variable chan
      global myserver
      catch {
        puts "reset... 1"
        chan event $chan readable {}
        puts "reset... 2"
        close $chan
        puts "reset... 3"
      }
      catch {
        puts "reconnecting... 1"
        set chan [socket -async $myserver 12345]
        puts "reconnecting... 2"
        chan configure $chan -encoding utf-8 -blocking 0 -buffering line
        puts "reconnecting... 3"
        chan event $chan readable "[namespace current]::handle'event"
        puts "reconnecting... 4"
      }
    }

    proc interval { } {
      variable chan
      variable lasttime
      set now [clock seconds]

      update idletasks
      after 1000 "[namespace current]::interval"
      if { [expr { $now - $lasttime }] > 3 } {
        if { [catch { chan puts $chan "" }] } {
          [namespace current]::reconnect
        }
      }
    }
    interval
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

proc sendfile { chan filepath } {
  set fp [open $filepath]
  fconfigure $fp -translation binary
  fconfigure $chan -translation binary
  fcopy $fp $chan; # Esto es para enviar archivos binarios
  close $fp
}

proc isnumeric value {
  if {![catch {expr {abs($value)}}]} {
    return 1
  }
  set value [string trimleft $value 0]
  if {![catch {expr {abs($value)}}]} {
    return 1
  }
  return 0
}


package require json::write
json::write indented 0
proc toJSON { row description } {
  set json_to_eval [list]
  foreach key [dict keys $description] {
    set jsontype [dict get [dict get $description $key] jsontype]
    set value [dict get $row $key]
    if { $jsontype == "string" } {
      lappend json_to_eval $key [json::write string $value]
    } elseif { $jsontype == "boolean" } {
      if { $value == "" } {
        lappend json_to_eval $key null
      } elseif { $value == "null" } {
        lappend json_to_eval $key null
      } elseif { $value } {
        lappend json_to_eval $key true
      } else {
        lappend json_to_eval $key false
      }
    } else {
      if { $value == "" } {
        lappend json_to_eval $key null
      } else {
        lappend json_to_eval $key [dict get $row $key]
      }
    }
  }
  return [eval "json::write object $json_to_eval"]
}
