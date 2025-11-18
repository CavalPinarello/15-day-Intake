#!/usr/bin/env python3
"""
Script to fetch all main components and tasks from Linear
"""
import sys
import os
import json
from datetime import datetime

# Add parent directory to path to import linear_client
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from linear_client import LinearClient

def format_date(date_str):
    """Format ISO date string to readable format"""
    if not date_str:
        return "N/A"
    try:
        dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        return dt.strftime("%Y-%m-%d %H:%M")
    except:
        return date_str

def get_all_issues_for_component(client, project, component_title):
    """Get all issues that belong to a component"""
    all_issues = project.get("issues", [])
    component_issues = []
    
    # Extract component prefix (e.g., "Component 1" from "Component 1: Title")
    component_prefix = None
    if ":" in component_title:
        component_prefix = component_title.split(":")[0].strip()
    else:
        import re
        match = re.match(r"(Component\s+\d+)", component_title)
        if match:
            component_prefix = match.group(1)
    
    for issue in all_issues:
        issue_title = issue.get("title", "")
        # Check if issue belongs to this component
        if component_prefix and component_prefix in issue_title:
            component_issues.append(issue)
        # Also check if it's a child of the component issue
        parent = issue.get("parent", {})
        if parent and component_prefix and component_prefix in parent.get("title", ""):
            component_issues.append(issue)
    
    return component_issues

def fetch_all_linear_data():
    """Fetch all components and tasks from Linear"""
    # Initialize client with API key
    api_key = os.getenv("LINEAR_API_KEY", "your-linear-api-key-here")
    client = LinearClient(api_key)
    
    project_name = "ZOE scope"
    
    print("="*80)
    print(f"Fetching Linear data from project: {project_name}")
    print("="*80)
    
    # Get the full project with all issues
    print("\n1. Fetching project and all issues...")
    project = client.get_project_with_issues(project_name)
    
    if not project:
        print(f"ERROR: Project '{project_name}' not found!")
        return
    
    all_issues = project.get("issues", [])
    print(f"   ✓ Found {len(all_issues)} total issues")
    
    # Get main components
    print("\n2. Identifying main components...")
    parent_categories = client.get_parent_categories(project_name)
    main_components = [c for c in parent_categories if c.get("type") == "component"]
    print(f"   ✓ Found {len(main_components)} main components")
    
    # Structure the data
    components_data = []
    
    for component_info in main_components:
        component_id = component_info.get("identifier")
        component_title = component_info.get("title")
        
        print(f"\n3. Processing component: {component_id} - {component_title}")
        
        # Find the main component issue
        main_component_issue = None
        for issue in all_issues:
            if issue.get("identifier") == component_id:
                main_component_issue = issue
                break
        
        # Get all issues for this component
        component_issues = get_all_issues_for_component(client, project, component_title)
        
        # Also get explicit children
        if main_component_issue:
            explicit_children = main_component_issue.get("children", {}).get("nodes", [])
            # Merge with component issues
            child_ids = {issue.get("identifier") for issue in component_issues}
            for child in explicit_children:
                if child.get("identifier") not in child_ids:
                    # Find full issue data
                    for issue in all_issues:
                        if issue.get("identifier") == child.get("identifier"):
                            component_issues.append(issue)
                            break
        
        # Remove duplicates based on identifier
        seen = set()
        unique_issues = []
        for issue in component_issues:
            issue_id = issue.get("identifier")
            if issue_id and issue_id not in seen:
                seen.add(issue_id)
                unique_issues.append(issue)
        
        # Sort issues by identifier
        unique_issues.sort(key=lambda x: x.get("identifier", ""))
        
        print(f"   ✓ Found {len(unique_issues)} tasks/issues")
        
        component_data = {
            "component": {
                "identifier": component_id,
                "title": component_title,
                "state": component_info.get("state"),
                "priority": component_info.get("priority"),
                "children_count": len(unique_issues),
                "full_issue": main_component_issue
            },
            "tasks": []
        }
        
        # Process each task
        for issue in unique_issues:
            # Skip the main component issue itself
            if issue.get("identifier") == component_id:
                continue
                
            task_data = {
                "identifier": issue.get("identifier"),
                "title": issue.get("title"),
                "description": issue.get("description"),
                "state": {
                    "name": issue.get("state", {}).get("name"),
                    "type": issue.get("state", {}).get("type")
                },
                "priority": issue.get("priority"),
                "assignee": {
                    "name": issue.get("assignee", {}).get("name"),
                    "email": issue.get("assignee", {}).get("email")
                } if issue.get("assignee") else None,
                "creator": {
                    "name": issue.get("creator", {}).get("name"),
                    "email": issue.get("creator", {}).get("email")
                } if issue.get("creator") else None,
                "parent": {
                    "identifier": issue.get("parent", {}).get("identifier"),
                    "title": issue.get("parent", {}).get("title")
                } if issue.get("parent") else None,
                "children_count": len(issue.get("children", {}).get("nodes", [])),
                "created_at": issue.get("createdAt"),
                "updated_at": issue.get("updatedAt"),
                "full_issue": issue
            }
            
            component_data["tasks"].append(task_data)
        
        components_data.append(component_data)
    
    # Get all other tasks not in components
    print("\n4. Finding tasks not assigned to components...")
    component_identifiers = {c["component"]["identifier"] for c in components_data}
    component_task_identifiers = set()
    for comp_data in components_data:
        component_task_identifiers.add(comp_data["component"]["identifier"])
        for task in comp_data["tasks"]:
            component_task_identifiers.add(task["identifier"])
    
    other_tasks = []
    for issue in all_issues:
        if issue.get("identifier") not in component_task_identifiers:
            other_tasks.append(issue)
    
    print(f"   ✓ Found {len(other_tasks)} tasks not in components")
    
    # Create final data structure
    output_data = {
        "project": {
            "name": project_name,
            "id": project.get("id"),
            "description": project.get("description"),
            "state": project.get("state"),
            "progress": project.get("progress"),
            "total_issues": len(all_issues),
            "fetched_at": datetime.now().isoformat()
        },
        "components": components_data,
        "other_tasks": [
            {
                "identifier": issue.get("identifier"),
                "title": issue.get("title"),
                "description": issue.get("description"),
                "state": {
                    "name": issue.get("state", {}).get("name"),
                    "type": issue.get("state", {}).get("type")
                },
                "priority": issue.get("priority"),
                "assignee": {
                    "name": issue.get("assignee", {}).get("name"),
                    "email": issue.get("assignee", {}).get("email")
                } if issue.get("assignee") else None,
                "created_at": issue.get("createdAt"),
                "updated_at": issue.get("updatedAt")
            }
            for issue in other_tasks
        ]
    }
    
    # Save to JSON file
    json_file = os.path.join(os.path.dirname(__file__), "..", "data", "linear_data.json")
    os.makedirs(os.path.dirname(json_file), exist_ok=True)
    
    with open(json_file, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    
    print(f"\n✓ Saved JSON data to: {json_file}")
    
    # Create markdown summary
    md_file = os.path.join(os.path.dirname(__file__), "..", "data", "linear_data.md")
    with open(md_file, "w", encoding="utf-8") as f:
        f.write(f"# Linear Data Export\n\n")
        f.write(f"**Project:** {project_name}\n")
        f.write(f"**Fetched:** {format_date(output_data['project']['fetched_at'])}\n")
        f.write(f"**Total Issues:** {len(all_issues)}\n")
        f.write(f"**Main Components:** {len(components_data)}\n\n")
        
        f.write("---\n\n")
        f.write("## Main Components\n\n")
        
        for comp_data in components_data:
            comp = comp_data["component"]
            f.write(f"### {comp['identifier']}: {comp['title']}\n\n")
            f.write(f"- **State:** {comp['state']}\n")
            f.write(f"- **Priority:** {comp['priority']}\n")
            f.write(f"- **Tasks:** {len(comp_data['tasks'])}\n\n")
            
            if comp_data["tasks"]:
                f.write("#### Tasks\n\n")
                for task in comp_data["tasks"]:
                    f.write(f"- **{task['identifier']}** - {task['title']}\n")
                    f.write(f"  - State: {task['state']['name']} ({task['state']['type']})\n")
                    if task['priority']:
                        f.write(f"  - Priority: {task['priority']}\n")
                    if task['assignee']:
                        f.write(f"  - Assignee: {task['assignee']['name']}\n")
                    if task['parent']:
                        f.write(f"  - Parent: {task['parent']['identifier']}\n")
                    if task['description']:
                        desc = task['description'][:200].replace('\n', ' ')
                        f.write(f"  - Description: {desc}...\n")
                    f.write("\n")
            
            f.write("\n---\n\n")
        
        if other_tasks:
            f.write("## Other Tasks (Not in Components)\n\n")
            for task in other_tasks[:50]:  # Limit to first 50
                f.write(f"- **{task.get('identifier')}** - {task.get('title')}\n")
                f.write(f"  - State: {task.get('state', {}).get('name', 'N/A')}\n")
            if len(other_tasks) > 50:
                f.write(f"\n*... and {len(other_tasks) - 50} more tasks*\n")
    
    print(f"✓ Saved Markdown summary to: {md_file}")
    
    # Print summary
    print("\n" + "="*80)
    print("SUMMARY")
    print("="*80)
    print(f"Project: {project_name}")
    print(f"Total Issues: {len(all_issues)}")
    print(f"Main Components: {len(components_data)}")
    total_tasks = sum(len(c["tasks"]) for c in components_data)
    print(f"Tasks in Components: {total_tasks}")
    print(f"Other Tasks: {len(other_tasks)}")
    print(f"\nFiles created:")
    print(f"  - {json_file}")
    print(f"  - {md_file}")
    print("="*80)

if __name__ == "__main__":
    fetch_all_linear_data()

