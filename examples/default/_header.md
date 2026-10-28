# Default example

A StandardV2 NAT gateway with a public IP address and a /31 public IP prefix it creates, and a virtual
network whose workload subnet sends its outbound traffic through it (three outbound addresses in all).

Run it with `scripts/e2e.sh examples/default`: apply, a second plan that must be empty, destroy.
