# Kubectl Troubleshooting Guide

## Pod Issues

### ImagePullBackOff / ErrImagePull

**Symptoms:**
```text
NAME         READY   STATUS             RESTARTS   AGE
myapp-xxx    0/1     ImagePullBackOff   0          5m
```

**Diagnosis:**
```bash
kubectl -n <namespace> describe pod <pod-name>
kubectl -n <namespace> get deploy <name> -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl -n <namespace> get secret <pull-secret-name> -o yaml
```

**Common causes:**
- wrong image name or tag
- missing registry credentials
- image not published yet
- network or registry outage

**Generic registry secret refresh pattern:**
```bash
kubectl -n <namespace> create secret docker-registry <pull-secret-name> \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password-or-token> \
  --dry-run=client -o yaml | kubectl apply -f -
```

### CrashLoopBackOff

**Diagnosis:**
```bash
kubectl -n <namespace> logs <pod-name>
kubectl -n <namespace> logs --previous <pod-name>
kubectl -n <namespace> get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
```

**Common causes:**
| Exit Code | Meaning | Common fix |
|-----------|---------|------------|
| 0 | Process exited cleanly but restarts | check probes or command lifecycle |
| 1 | Application error | inspect app logs and config |
| 137 | OOMKilled | increase memory or reduce usage |
| 143 | SIGTERM | inspect graceful shutdown path |

### Pending

**Diagnosis:**
```bash
kubectl -n <namespace> describe pod <pod-name>
kubectl describe nodes
kubectl -n <namespace> get pvc
```

**Common causes:**
- insufficient CPU or memory
- node selector or affinity mismatch
- PVC not bound
- taints without matching tolerations

### OOMKilled

**Diagnosis:**
```bash
kubectl -n <namespace> get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
kubectl -n <namespace> top pod <pod-name>
kubectl -n <namespace> get pod <pod-name> -o jsonpath='{.spec.containers[0].resources.limits.memory}'
```

## Service Issues

### Service Has No Endpoints

**Diagnosis:**
```bash
kubectl -n <namespace> get endpoints <service-name>
kubectl -n <namespace> get svc <service-name> -o jsonpath='{.spec.selector}'
kubectl -n <namespace> get pods --show-labels
kubectl -n <namespace> get pods -l <selector>
```

**Common causes:**
- selector does not match pod labels
- pods are not Ready
- resources are in different namespaces

### Connection Refused

**Diagnosis:**
```bash
kubectl -n <namespace> get pods -l <selector>
kubectl -n <namespace> get pod <pod-name> -o jsonpath='{.spec.containers[0].ports}'
kubectl -n <namespace> exec -it <another-pod> -- curl <service>:<port>
kubectl -n <namespace> get networkpolicies
```

## Deployment Issues

### Deployment Stuck

**Diagnosis:**
```bash
kubectl -n <namespace> rollout status deployment/<name>
kubectl -n <namespace> describe deployment <name>
kubectl -n <namespace> get rs -l app=<name>
kubectl -n <namespace> get pods -l app=<name>
```

**Common causes:**
- new pods fail to start
- readiness probe failures
- quota or limit constraints
- image pull failures

**Common recovery options:**
```bash
kubectl -n <namespace> rollout history deployment/<name>
kubectl -n <namespace> rollout restart deployment/<name>
# destructive: require explicit confirmation before rollback
kubectl -n <namespace> rollout undo deployment/<name>
```

## Node Issues

### Node NotReady

**Diagnosis:**
```bash
kubectl get nodes
kubectl describe node <node-name>
```

**Common causes:**
- kubelet not running
- network partition
- disk pressure
- memory pressure

### Evicted Pods

**Diagnosis:**
```bash
kubectl -n <namespace> get pods --field-selector=status.phase=Failed
kubectl -n <namespace> describe pod <evicted-pod>
kubectl describe node <node-name>
```

## Resource Pressure

### High CPU or Memory Usage

**Diagnosis:**
```bash
kubectl -n <namespace> top pods --sort-by=cpu
kubectl -n <namespace> top pods --sort-by=memory
kubectl top nodes
kubectl -n <namespace> get resourcequota
kubectl -n <namespace> get limitrange
```

**Follow-up questions:**
- Is the workload under-provisioned or leaking memory?
- Are limits much lower than observed steady-state usage?
- Is autoscaling configured and healthy?

## General Debugging Pattern

When a Kubernetes issue is unclear, collect these in order:
1. `kubectl config current-context`
2. `kubectl -n <namespace> get pods,svc,deploy`
3. `kubectl -n <namespace> describe <resource> <name>`
4. `kubectl -n <namespace> logs <pod-name>` and `--previous`
5. `kubectl -n <namespace> get events --sort-by=.lastTimestamp`
6. `kubectl -n <namespace> top pods` and `kubectl top nodes`

Prefer reporting the exact failing condition from events, probe errors, image pull errors, or scheduling messages instead of guessing.
