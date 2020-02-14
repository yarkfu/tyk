path "/concourse/*" {
  policy = "write"
  capabilities = [ "create", "read", "update", "list", "delete", "sudo" ]
}

# Allow renewal of token leases
path "auth/token/renew-self" {
    policy = "write"
}
