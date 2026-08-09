# GitHub Projects (gh project)

## List Projects

```bash
# List projects
gh project list

# List for owner
gh project list --owner owner

# List open projects only
gh project list --open
```

## View Project

```bash
# View project
gh project view 123

# View project items as JSON
gh project view 123 --format json

# View in browser
gh project view 123 --web
```

## Create Project

```bash
# Create project
gh project create --title "My Project"

# Create in organization
gh project create --title "Project" --org orgname

# Create with readme
gh project create --title "Project" --readme "Description here"
```

## Edit Project

```bash
# Edit project title
gh project edit 123 --title "New Title"
```

## Delete/Close Project

```bash
# Delete project
gh project delete 123

# Close project
gh project close 123
```

## Copy Project

```bash
# Copy project
gh project copy 123 --owner target-owner --title "Copy"
```

## Mark as Template

```bash
# Mark project as template
gh project mark-template 123
```

## Fields

```bash
# List fields
gh project field-list 123

# Create field
gh project field-create 123 --title "Status" --datatype single_select

# Delete field
gh project field-delete 123 --id 456
```

## Items

```bash
# List items
gh project item-list 123

# Create item
gh project item-create 123 --title "New item"

# Add existing issue/PR to project
gh project item-add 123 --owner owner --repo repo --issue 456

# Edit item
gh project item-edit 123 --id 456 --title "Updated title"

# Delete item
gh project item-delete 123 --id 456

# Archive item
gh project item-archive 123 --id 456
```

## Links

```bash
# Link items
gh project link 123 --id 456 --link-id 789

# Unlink items
gh project unlink 123 --id 456 --link-id 789
```
