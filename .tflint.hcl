# tflint for every layer in terraform/ (`just check` runs it in each). The bundled
# "terraform" ruleset with every rule on: unused declarations, missing descriptions and
# types, deprecated syntax, naming, pinned provider versions.
plugin "terraform" {
  enabled = true
  preset  = "all"
}

# The edge layer splits its resources by domain (access.tf, dns.tf, tunnel.tf) instead of a
# main.tf — the split AGENTS.md prescribes once a file grows. The rule wants main.tf anyway.
rule "terraform_standard_module_structure" {
  enabled = false
}
