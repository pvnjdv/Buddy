#!/usr/bin/env python3
"""
Database migration to add profession column to users table
"""
import sqlite3
import os
import sys

def add_profession_column():
    """Add profession column to users table if it doesn't exist"""
    
    # Database file path
    db_path = os.path.join(os.path.dirname(__file__), 'buddy.db')
    
    try:
        # Connect to database
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if profession column exists
        cursor.execute("PRAGMA table_info(users)")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'profession' not in columns:
            print("Adding profession column to users table...")
            cursor.execute("ALTER TABLE users ADD COLUMN profession TEXT")
            conn.commit()
            print("✅ Successfully added profession column")
        else:
            print("✅ Profession column already exists")
            
    except sqlite3.Error as e:
        print(f"❌ Database error: {e}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    finally:
        if conn:
            conn.close()
    
    return True

if __name__ == "__main__":
    print("🔄 Running database migration...")
    success = add_profession_column()
    
    if success:
        print("✅ Migration completed successfully!")
        sys.exit(0)
    else:
        print("❌ Migration failed!")
        sys.exit(1)
