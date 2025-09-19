#!/usr/bin/env python3
"""
Test script for GitHub repository creation integration
Run this to test if GitHub PAT and repository creation works
"""
import asyncio
import os
from app.services.github_service import GitHubService

async def test_github_integration():
    """Test GitHub repository creation"""
    print("Testing GitHub Integration...")

    # Check if GitHub PAT is configured
    github_pat = os.getenv("GITHUB_PAT")
    if not github_pat:
        print("❌ GITHUB_PAT not found in environment variables")
        print("Please set your GitHub Personal Access Token:")
        print("export GITHUB_PAT=your_token_here")
        return

    print("✅ GitHub PAT found")

    # Initialize GitHub service
    github_service = GitHubService()

    # Test repository creation
    test_user_mobile = "1234567890"
    test_project_name = "test_project"

    print(f"Creating repository: {test_user_mobile}_{test_project_name}")

    result = await github_service.create_flow_repository(
        user_mobile=test_user_mobile,
        project_name=test_project_name,
        description="Test repository for Buddy integration"
    )

    if result['success']:
        print("✅ Repository created successfully!")
        print(f"Repository: {result['repository']['html_url']}")
        print(f"Local path: {result['local_path']}")
    else:
        print(f"❌ Repository creation failed: {result['error']}")

if __name__ == "__main__":
    asyncio.run(test_github_integration())