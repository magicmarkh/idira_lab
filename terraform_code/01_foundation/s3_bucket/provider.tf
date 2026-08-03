# No provider block here on purpose.
#
# This child module inherits the default (unaliased) aws provider from the
# root module (../provider.tf), which is configured with credentials fetched
# from Conjur. Declaring a bare `provider "aws" { region = ... }` here would
# create a SEPARATE provider configuration with no credentials, falling back
# to the ambient AWS credential chain (env vars / ~/.aws/credentials) — which
# breaks with InvalidClientTokenId once the automation access key is rotated.
