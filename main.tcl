
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
