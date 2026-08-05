# JSONPath and Output Formatting Reference

Use structured output before resorting to plain-text parsing.

## JSONPath Basics

```bash
# Single field
kubectl -n <namespace> get pod <name> -o jsonpath='{.metadata.name}'

# Nested field
kubectl -n <namespace> get pod <name> -o jsonpath='{.status.phase}'

# Array element
kubectl -n <namespace> get pod <name> -o jsonpath='{.spec.containers[0].name}'

# All array elements
kubectl -n <namespace> get pods -o jsonpath='{.items[*].metadata.name}'
```

## Common Patterns

### Pod Information

```bash
# Pod names with newlines
kubectl -n <namespace> get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'

# Pod name and status
kubectl -n <namespace> get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Container images
kubectl -n <namespace> get pods -o jsonpath='{.items[*].spec.containers[*].image}'

# Pod IPs
kubectl -n <namespace> get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'
```

### Deployment Information

```bash
# Current image
kubectl -n <namespace> get deploy <name> -o jsonpath='{.spec.template.spec.containers[0].image}'

# Replica status
kubectl -n <namespace> get deploy <name> -o jsonpath='Desired: {.spec.replicas}, Available: {.status.availableReplicas}'

# All deployment images
kubectl -n <namespace> get deploy -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

### Service Information

```bash
# Service ClusterIP
kubectl -n <namespace> get svc <name> -o jsonpath='{.spec.clusterIP}'

# LoadBalancer hostnames or IPs
kubectl -n <namespace> get svc <name> -o jsonpath='{.status.loadBalancer.ingress[*].hostname}{.status.loadBalancer.ingress[*].ip}'

# Service ports
kubectl -n <namespace> get svc <name> -o jsonpath='{range .spec.ports[*]}{.port}{":"}{.targetPort}{"\n"}{end}'
```

### Node Information

```bash
# Node internal IPs
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'

# Node capacity
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}CPU:{.status.capacity.cpu}{"\t"}Mem:{.status.capacity.memory}{"\n"}{end}'
```

### Secret Handling

Prefer extracting only the key you need.

```bash
# Decode a single secret key
kubectl -n <namespace> get secret <name> -o jsonpath='{.data.<key>}' | base64 -d

# List available secret keys
kubectl -n <namespace> get secret <name> -o jsonpath='{.data}' | jq 'keys'
```

## Filtering with JSONPath

```bash
# Pods on a specific node
kubectl -n <namespace> get pods -o jsonpath='{.items[?(@.spec.nodeName=="node-1")].metadata.name}'

# Running pods only
kubectl -n <namespace> get pods -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}'

# Containers using a specific image
kubectl -n <namespace> get pods -o jsonpath='{.items[*].spec.containers[?(@.image=="nginx")].name}'
```

## Custom Columns

```bash
# Basic custom columns
kubectl -n <namespace> get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase

# Multi-column pod report
kubectl -n <namespace> get pods -o custom-columns='POD:.metadata.name,STATUS:.status.phase,IP:.status.podIP,NODE:.spec.nodeName'

# Resource requests
kubectl -n <namespace> get pods -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory'
```

## Go Templates

```bash
# Basic template
kubectl -n <namespace> get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'

# Running pods only
kubectl -n <namespace> get pods -o go-template='{{range .items}}{{if eq .status.phase "Running"}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}'

# Formatted table
kubectl -n <namespace> get pods -o go-template='{{range .items}}{{printf "%-40s %-10s\n" .metadata.name .status.phase}}{{end}}'
```

## Sorting

```bash
kubectl -n <namespace> get pods --sort-by=.metadata.creationTimestamp
kubectl -n <namespace> get pods --sort-by=.status.containerStatuses[0].restartCount
kubectl -n <namespace> get pods --sort-by=.metadata.name
```

## Combining with Shell Tools

```bash
# Count pods by phase
kubectl -n <namespace> get pods -o jsonpath='{.items[*].status.phase}' | tr ' ' '\n' | sort | uniq -c

# Highest memory consumers
kubectl -n <namespace> top pods --no-headers | sort -k3 -h | tail -5

# Export as CSV
kubectl -n <namespace> get pods -o jsonpath='{range .items[*]}{.metadata.name},{.status.phase},{.status.podIP}{"\n"}{end}'
```
