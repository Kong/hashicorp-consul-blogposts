exec {
  command = "echo 'done'"
}
template {
  source = "ca.crt.tmpl"
  destination = "ca.crt"
}
template {
  source = "cert.pem.tmpl"
  destination = "cert.pem"
}
template {
  source = "cert.key.tmpl"
  destination = "cert.key"
}
