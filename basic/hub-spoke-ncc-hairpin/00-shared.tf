##################################
# Random Items                   #
##################################
resource "random_id" "secret" {
  byte_length = 8
}

resource "random_id" "id" {
  byte_length = 2
}
