# Codespaces (gh codespace)

## List Codespaces

```bash
# List codespaces
gh codespace list
```

## Create Codespace

```bash
# Create codespace
gh codespace create

# Create with specific repository
gh codespace create --repo owner/repo

# Create with branch
gh codespace create --branch develop

# Create with specific machine type
gh codespace create --machine premiumLinux
```

## View Codespace

```bash
# View codespace details
gh codespace view
```

## Connect to Codespace

```bash
# SSH into codespace
gh codespace ssh

# SSH with specific command
gh codespace ssh --command "cd /workspaces && ls"

# Open codespace in browser
gh codespace code

# Open in VS Code desktop
gh codespace code --codec

# Open with specific path
gh codespace code --path /workspaces/repo
```

## Stop Codespace

```bash
# Stop codespace
gh codespace stop
```

## Delete Codespace

```bash
# Delete codespace
gh codespace delete
```

## Logs

```bash
# View logs
gh codespace logs

# Tail logs
gh codespace logs --tail 100
```

## Ports

```bash
# View ports
gh codespace ports

# Forward port
gh codespace ports forward 8080:8080
```

## Rebuild Codespace

```bash
# Rebuild codespace
gh codespace rebuild
```

## Edit Codespace

```bash
# Edit codespace machine type
gh codespace edit --machine standardLinux
```

## Jupyter

```bash
# Open Jupyter in codespace
gh codespace jupyter
```

## Copy Files

```bash
# Copy file to codespace
gh codespace cp file.txt remote:/workspaces/file.txt

# Copy file from codespace
gh codespace cp remote:/workspaces/file.txt ./file.txt
```
