
# Leer el TCL Style
# Escribir pruebas para este deserializador

# Convierte una string en un dict
#
# string - cadena a deserializar
# result - dict que contiene la string convertida en dict
proc deserialize { string result } {
  # Muestre como serializar el dict
  upvar $result r
  set r [dict create]
  set key ""
  foreach step $string {
    if { $key == "" } {
      set key $step
    } else {
      dict set r $key $step
      set key ""
    }
  }
}
