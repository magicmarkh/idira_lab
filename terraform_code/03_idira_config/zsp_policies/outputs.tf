output "policy_id" {
  description = "The generated ID of the ZSP VM access policy"
  value       = idsec_policy_vm.this.metadata.policy_id
}

output "policy_name" {
  description = "The name of the ZSP VM access policy"
  value       = idsec_policy_vm.this.metadata.name
}
