"""
Migration script to add refresh token columns to the users table
Run this script to update the database schema
"""

import sqlite3
import os

def migrate_database():
    # Path to the database
    db_path = "/home/pvn/Desktop/Buddy/buddy_backend/buddy.db"
    
    if not os.path.exists(db_path):
        print(f"Database not found at {db_path}")
        return
    
    # Connect to the database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check if columns already exist
        cursor.execute("PRAGMA table_info(users)")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'refresh_token' not in columns:
            print("Adding refresh_token column...")
            cursor.execute("ALTER TABLE users ADD COLUMN refresh_token TEXT")
        else:
            print("refresh_token column already exists")
            
        if 'refresh_token_expires' not in columns:
            print("Adding refresh_token_expires column...")
            cursor.execute("ALTER TABLE users ADD COLUMN refresh_token_expires DATETIME")
        else:
            print("refresh_token_expires column already exists")
        
        # Commit changes
        conn.commit()
        print("✅ Database migration completed successfully!")
        
        # Show updated table structure
        cursor.execute("PRAGMA table_info(users)")
        columns = cursor.fetchall()
        print("\nUpdated users table structure:")
        for column in columns:
            print(f"  - {column[1]} ({column[2]})")
            
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    migrate_database()
