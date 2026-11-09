# Runners

Runner choice changes the rate per minute, the speed, or both. Compare cost per job: cost ∝ rate ratio ÷ speed-up, measured on the same workflow. Rates: https://cicdpipelinecost.com/github-actions-pricing.

## Right-sizing

- Profile CPU and memory during the job. Downsize when utilisation stays low; the build will not slow.
- Upsize when the job is CPU-bound and on the critical path. A larger runner lowers the bill only when its speed-up exceeds its rate ratio; otherwise it buys wait time, and that trade waits for a human.
- Queue time: larger and specialised runners can queue longer than standard ones. Include queue time in the comparison.

## ARM Linux

Rates and current compatibility notes: https://cicdpipelinecost.com/arm-runners.

- Usually works unchanged: Node, Python, Go, Rust, Java, Ruby, PHP, and multi-stage Docker builds via buildx.
- Usually breaks: x86 intrinsics (SSE/AVX), x86-only binaries, older Electron, some CUDA/ML paths, some CGo dependencies, Chromium-based E2E.
- Migrate by changing `runs-on`, running the workflow on a branch, and comparing duration and results with the x86 baseline. Adopt only when cost per job drops.

## External managed runners

Managed runner providers (current roster and rates: https://cicdpipelinecost.com/depot-vs-namespace-vs-blacksmith) are drop-in `runs-on` label changes with built-in warm caches. They differ in rate, macOS support, start-up latency, and whether jobs run in your cloud account or on vendor hardware. Trial on one workflow, then time queue-to-start and total duration before rolling out. Security review covers the vendor's isolation model, OIDC in place of long-lived secrets, and data residency.

## Self-hosted

Current fee status and volume break-even: https://cicdpipelinecost.com/self-hosted-runners. Count maintenance (patching, autoscaling, spot interruptions, runner upgrades) at loaded engineer cost alongside compute.

Self-hosting pays back only when one of these holds:

- Sustained high volume with a dedicated platform team.
- GPU or specialised hardware.
- Compliance requiring VPC-isolated or on-prem builds.
- High-volume macOS (Mac minis or a hosted Mac fleet).

Options by operational burden, lowest first: a managed control plane on your cloud account, `philips-labs/terraform-aws-github-runner` (ephemeral EC2), Actions Runner Controller on Kubernetes, Karpenter-managed pools. Autoscaled fleets add cold-start queue time; warm pools trade idle cost for it. Spot fleets need diversified instance types, and interruption re-runs belong in the minute estimate. Never attach self-hosted runners to public repositories: any fork PR can execute code on them.

## macOS

macOS is the most expensive hosted runner and drains included minutes fastest. The reliable saving is frequency: run macOS jobs only for Apple-specific code, on release branches or the merge queue, and keep PR checks on Linux.
