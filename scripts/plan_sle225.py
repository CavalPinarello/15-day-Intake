#!/usr/bin/env python3
"""
Plan and update Linear tasks for SLE-225 (Supporting Systems)
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from linear_client import LinearClient

def get_viewer_info(client):
    """Get current user (viewer) information"""
    query = """
    query {
        viewer {
            id
            name
            email
        }
    }
    """
    result = client.query(query)
    return result.get("data", {}).get("viewer", {})

def assign_issue(client, issue_id, user_id):
    """Assign an issue to a user"""
    mutation = """
    mutation($issueId: String!, $userId: String!) {
        issueUpdate(id: $issueId, input: { assigneeId: $userId }) {
            success
            issue {
                id
                identifier
                title
                assignee {
                    name
                    email
                }
            }
        }
    }
    """
    variables = {
        "issueId": issue_id,
        "userId": user_id
    }
    return client.query(mutation, variables)

def update_issue_state(client, issue_id, state_id):
    """Update issue state (e.g., move to In Progress)"""
    mutation = """
    mutation($issueId: String!, $stateId: String!) {
        issueUpdate(id: $issueId, input: { stateId: $stateId }) {
            success
            issue {
                id
                identifier
                title
                state {
                    name
                    type
                }
            }
        }
    }
    """
    variables = {
        "issueId": issue_id,
        "stateId": state_id
    }
    return client.query(mutation, variables)

def get_workflow_states(client, team_key="SLE"):
    """Get workflow states for a team"""
    try:
        query = """
        query($teamKey: String!) {
            team(key: $teamKey) {
                states {
                    nodes {
                        id
                        name
                        type
                    }
                }
            }
        }
        """
        variables = {"teamKey": team_key}
        result = client.query(query, variables)
        return result.get("data", {}).get("team", {}).get("states", {}).get("nodes", [])
    except Exception as e:
        print(f"   ⚠ Could not fetch workflow states: {e}")
        return []

def get_issue_by_identifier(client, identifier):
    """Get issue by identifier (e.g., SLE-225)"""
    query = """
    query($identifier: String!) {
        issue(identifier: $identifier) {
            id
            identifier
            title
            description
            state {
                id
                name
                type
            }
            assignee {
                id
                name
                email
            }
            children {
                nodes {
                    id
                    identifier
                    title
                    state {
                        id
                        name
                    }
                    assignee {
                        id
                        name
                    }
                }
            }
        }
    }
    """
    variables = {"identifier": identifier}
    result = client.query(query, variables)
    return result.get("data", {}).get("issue")

def plan_and_update_sle225():
    """Plan SLE-225 work and update Linear tasks"""
    api_key = os.getenv("LINEAR_API_KEY", "your-linear-api-key-here")
    client = LinearClient(api_key)
    
    print("="*80)
    print("SLE-225: Supporting Systems - Planning & Task Assignment")
    print("="*80)
    
    # Get current user info
    print("\n1. Getting current user information...")
    viewer = get_viewer_info(client)
    if not viewer:
        print("ERROR: Could not get viewer information")
        return
    
    user_id = viewer.get("id")
    user_name = viewer.get("name", "Unknown")
    user_email = viewer.get("email", "Unknown")
    
    print(f"   ✓ Current user: {user_name} ({user_email})")
    print(f"   ✓ User ID: {user_id}")
    
    # Get workflow states (optional)
    print("\n2. Getting workflow states...")
    states = get_workflow_states(client, "SLE")
    state_map = {state["name"]: state for state in states} if states else {}
    
    if states:
        print(f"   ✓ Found {len(states)} workflow states")
        for state in states:
            print(f"      - {state['name']} ({state['type']})")
    else:
        print("   ⚠ Could not fetch workflow states - will skip state updates")
    
    # Get SLE-225 and its tasks using the existing working method
    print("\n3. Fetching SLE-225 component and tasks...")
    try:
        # Use the existing method that works
        project = client.get_project_with_issues("ZOE scope")
        all_issues = project.get("issues", [])
        
        # Find SLE-225 component
        component_issue = None
        for issue in all_issues:
            if issue.get("identifier") == "SLE-225":
                component_issue = issue
                break
        
        if not component_issue:
            print("ERROR: Could not find SLE-225")
            return
        
        print(f"   ✓ Component: {component_issue['identifier']} - {component_issue['title']}")
        print(f"   ✓ Current state: {component_issue['state']['name']}")
        print(f"   ✓ Current assignee: {component_issue['assignee']['name'] if component_issue.get('assignee') else 'Unassigned'}")
        
        # Find all tasks under SLE-225
        tasks = []
        task_identifiers = ["SLE-226", "SLE-227", "SLE-228", "SLE-229"]
        for issue in all_issues:
            if issue.get("identifier") in task_identifiers:
                parent = issue.get("parent", {})
                if parent and parent.get("identifier") == "SLE-225":
                    tasks.append(issue)
        
        print(f"   ✓ Found {len(tasks)} tasks")
    except Exception as e:
        print(f"ERROR: Could not fetch SLE-225 data: {e}")
        return
    
    # Display tasks
    print("\n4. Task Overview:")
    print("-" * 80)
    for i, task in enumerate(tasks, 1):
        assignee_name = task.get('assignee', {}).get('name') if task.get('assignee') else 'Unassigned'
        print(f"\n{i}. {task['identifier']}: {task['title']}")
        print(f"   State: {task['state']['name']}")
        print(f"   Assignee: {assignee_name}")
    
    # Plan the work
    print("\n" + "="*80)
    print("WORK PLAN")
    print("="*80)
    
    plan = """
    Based on the current project state and SLE-225 requirements, here's the implementation plan:

    PRIORITY ORDER:
    1. SLE-228: Authentication & Security (Foundation - needed first)
       - JWT authentication system
       - Password hashing with bcrypt
       - Refresh token rotation
       - Rate limiting
       - Security headers
       - This is critical as other systems depend on it

    2. SLE-227: Backend Infrastructure (Core foundation)
       - Database schema expansion (currently SQLite, plan for PostgreSQL migration)
       - Additional API endpoints
       - Background job system
       - WebSocket support for real-time features
       - Redis caching layer

    3. SLE-229: Notification System (User engagement)
       - Email notification system
       - Push notification infrastructure
       - Notification preferences
       - Template system

    4. SLE-226: Apple Health Integration (Feature enhancement)
       - HealthKit integration (iOS only)
       - Data sync endpoints
       - Health data storage schema
       - Background sync

    IMPLEMENTATION STRATEGY:
    - Start with authentication (SLE-228) as it's foundational
    - Enhance backend incrementally (SLE-227)
    - Add notifications (SLE-229) once backend is stable
    - Apple Health (SLE-226) can be done in parallel or after core systems

    CURRENT PROJECT STATE:
    - Basic Node.js/Express backend with SQLite
    - Hard-coded authentication (user1-user10)
    - Basic API endpoints for days/questions/responses
    - Next.js frontend

    NEXT STEPS:
    1. Implement proper JWT authentication (SLE-228)
    2. Expand database schema for supporting systems (SLE-227)
    3. Add notification infrastructure (SLE-229)
    4. Implement Apple Health sync (SLE-226)
    """
    
    print(plan)
    
    # Ask for confirmation before updating Linear
    print("\n" + "="*80)
    print("UPDATING LINEAR TASKS")
    print("="*80)
    
    # Find "In Progress" or "Started" state
    in_progress_state = None
    for state_name in ["In Progress", "Started", "Doing", "Active"]:
        if state_name in state_map:
            in_progress_state = state_map[state_name]
            break
    
    if not in_progress_state:
        print("   ⚠ Warning: Could not find 'In Progress' state. Tasks will remain in current state.")
    else:
        print(f"   ✓ Found state: {in_progress_state['name']}")
    
    # Assign and update tasks
    print("\n5. Assigning tasks to current user...")
    
    tasks_to_assign = [
        ("SLE-225", component_issue),
        ("SLE-228", next((t for t in tasks if t['identifier'] == 'SLE-228'), None)),
        ("SLE-227", next((t for t in tasks if t['identifier'] == 'SLE-227'), None)),
        ("SLE-229", next((t for t in tasks if t['identifier'] == 'SLE-229'), None)),
        ("SLE-226", next((t for t in tasks if t['identifier'] == 'SLE-226'), None)),
    ]
    
    for identifier, task_obj in tasks_to_assign:
        if not task_obj:
            print(f"   ⚠ {identifier}: Not found")
            continue
        
        task_id = task_obj['id']
        current_assignee = task_obj.get('assignee', {}).get('name') if task_obj.get('assignee') else None
        
        # Assign if not already assigned to us
        if current_assignee != user_name:
            try:
                result = assign_issue(client, task_id, user_id)
                if result.get("data", {}).get("issueUpdate", {}).get("success"):
                    print(f"   ✓ {identifier}: Assigned to {user_name}")
                else:
                    print(f"   ✗ {identifier}: Failed to assign")
            except Exception as e:
                print(f"   ✗ {identifier}: Error assigning - {e}")
        else:
            print(f"   ✓ {identifier}: Already assigned to {user_name}")
        
        # Update state to "In Progress" if available
        if in_progress_state and task_obj['state']['name'] == 'Backlog':
            try:
                result = update_issue_state(client, task_id, in_progress_state['id'])
                if result.get("data", {}).get("issueUpdate", {}).get("success"):
                    print(f"   ✓ {identifier}: Moved to '{in_progress_state['name']}'")
            except Exception as e:
                print(f"   ⚠ {identifier}: Could not update state - {e}")
    
    print("\n" + "="*80)
    print("SUMMARY")
    print("="*80)
    print(f"✓ Tasks assigned to: {user_name}")
    print(f"✓ Ready to start implementation")
    print(f"✓ Priority: Authentication → Backend → Notifications → Apple Health")
    print("="*80)

if __name__ == "__main__":
    plan_and_update_sle225()

