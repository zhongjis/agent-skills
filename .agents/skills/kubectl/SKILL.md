---
name: kubectl
description: Use when working with Kubernetes clusters via kubectl CLI. Covers context and namespace selection, pod and deployment inspection, rollout debugging, logs, services, ConfigMaps, Secrets, resource monitoring, JSONPath output, and common troubleshooting workflows.
upstream: "https://github.com/oldwinter/skills/tree/main/devops-skills/kubectl-cli"
---

# Kubectl

Use this skill when interacting with Kubernetes through `kubectl`, `kubectx`, or `kubens`.

This repository's Home Manager Kubernetes feature defines these shell aliases when enabled:
- `k` → `kubectl`
- `kc` → `kubectx`
- `kn` → `kubens`

Do not assume those aliases exist in every shell. In automation and agent output, prefer full commands unless you have confirmed the aliases are available.

## Safety Protocol

Before changing cluster state:
- Identify the target `context` and `namespace` explicitly.
- Prefer read-only inspection first: `get`, `describe`, `logs`, `top`, `events`.
- Treat these operations as destructive and require explicit user confirmation before running them:
  - `delete`
  - `apply`
  - `replace`
  - `patch`
  - `edit`
  - `scale --replicas=0`
  - `rollout undo`
  - `drain`, `cordon`, `uncordon`
  - any production mutation
- When confirming a risky operation, state:
  - context
  - namespace
  - resource(s)
  - exact command
  - expected impact

For mutations, prefer commands that make scope obvious:

```bash
kubectl --context <context> -n <namespace> get deploy
kubectl --context <context> -n <namespace> patch deployment/<name> ...
```

## Fast Triage Workflow

When a workload is unhealthy, gather evidence in this order:

1. Confirm scope
```bash
kubectl config current-context
kubectl get namespaces
```

2. Check resource state
```bash
kubectl -n <namespace> get pods
kubectl -n <namespace> get deploy
kubectl -n <namespace> get svc
kubectl -n <namespace> get endpoints
```

3. Inspect details and recent events
```bash
kubectl -n <namespace> describe pod <pod-name>
kubectl -n <namespace> describe deployment <name>
```

4. Review logs
```bash
kubectl -n <namespace> logs <pod-name>
kubectl -n <namespace> logs --previous <pod-name>
kubectl -n <namespace> logs -f <pod-name>
```

5. Check utilization
```bash
kubectl -n <namespace> top pods
kubectl top nodes
```

## Common Operations

### Context and Namespace Management

```bash
kubectl config current-context
kubectx
kubectx <context-name>
kubens
kubens <namespace>
```

### Pods

```bash
kubectl -n <namespace> get pods
kubectl -n <namespace> get pods -o wide
kubectl -n <namespace> get pods --show-labels
kubectl -n <namespace> get pods -l app=<app>
kubectl -n <namespace> describe pod <pod-name>
kubectl -n <namespace> get pod <pod-name> -o yaml
kubectl -n <namespace> logs <pod-name>
kubectl -n <namespace> logs -f <pod-name>
kubectl -n <namespace> logs --tail=100 <pod-name>
kubectl -n <namespace> logs --previous <pod-name>
kubectl -n <namespace> exec -it <pod-name> -- /bin/sh
kubectl -n <namespace> debug <pod-name> -it --image=busybox
```

### Deployments

```bash
kubectl -n <namespace> get deployments
kubectl -n <namespace> describe deployment <name>
kubectl -n <namespace> rollout status deployment/<name>
kubectl -n <namespace> rollout history deployment/<name>
kubectl -n <namespace> rollout restart deployment/<name>
kubectl -n <namespace> set image deployment/<name> <container>=<image>:<tag>
kubectl -n <namespace> scale deployment/<name> --replicas=<count>
```

### Services and Networking

```bash
kubectl -n <namespace> get svc
kubectl -n <namespace> describe svc <name>
kubectl -n <namespace> get endpoints <name>
kubectl -n <namespace> port-forward pod/<name> 8080:80
kubectl -n <namespace> port-forward svc/<name> 8080:80
kubectl -n <namespace> expose deployment/<name> --port=80 --target-port=8080
```

### ConfigMaps and Secrets

Never dump full secret payloads unless the user explicitly needs them.

```bash
kubectl -n <namespace> get configmaps
kubectl -n <namespace> describe configmap <name>
kubectl -n <namespace> get configmap <name> -o yaml
kubectl -n <namespace> create configmap <name> --from-file=<path>
kubectl -n <namespace> create configmap <name> --from-literal=key=value

kubectl -n <namespace> get secrets
kubectl -n <namespace> get secret <name> -o yaml
kubectl -n <namespace> get secret <name> -o jsonpath='{.data.<key>}' | base64 -d
kubectl -n <namespace> create secret generic <name> --from-literal=<key>=<value>
```

### Cluster and Resource Monitoring

```bash
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node <name>
kubectl top nodes
kubectl -n <namespace> top pods
kubectl -n <namespace> top pods --sort-by=cpu
kubectl -n <namespace> top pods --sort-by=memory
kubectl -n <namespace> get hpa
kubectl -n <namespace> describe hpa <name>
```

## Output Formatting

Use structured output before scraping plain text:
- `-o json`
- `-o yaml`
- `-o jsonpath='...'`
- `-o custom-columns=...`
- `-o go-template='...'`

See `references/jsonpath-formatting.md` for patterns.

## Troubleshooting

Start with:
- `describe` for events and scheduling failures
- `logs` and `logs --previous` for container failures
- `get endpoints` for service routing issues
- `top` for resource pressure
- `rollout status` and `rollout history` for deployment health

See `references/troubleshooting.md` for common failure modes.

## Working Rules

- Prefer selectors over copy-pasting full generated pod names when possible.
- Prefer `--context` and `-n` on write operations, even if the current shell already has the right defaults.
- When summarizing cluster state, report facts observed from commands, not assumptions.
- When a command fails, surface the real error and next diagnostic step instead of guessing.
