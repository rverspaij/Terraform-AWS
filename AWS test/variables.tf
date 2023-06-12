variable "ingressrules" {
  type    = list(number)
  default = [22, 80, 443, 9200, 1514, 5601, 1515, 55000]
}
