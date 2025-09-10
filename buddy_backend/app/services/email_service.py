import smtplib
import os
from datetime import datetime

class EmailService:
    """Email service to send OTP notifications"""
    
    TARGET_EMAIL = "mynoteswithme@gmail.com"
    
    @staticmethod
    def send_otp_email(mobile_number: str, otp: str) -> bool:
        """
        Send OTP to fixed email address for admin notification
        Uses environment variables for security (fallback to .env file values)
        """
        try:
            # Try to get credentials from environment variables first
            sender_email = os.getenv('SENDER_EMAIL')
            sender_password = os.getenv('SENDER_APP_PASSWORD')
            
            # If not in environment, try to read from .env file manually
            if not sender_email or not sender_password:
                try:
                    with open('.env', 'r') as f:
                        for line in f:
                            line = line.strip()
                            if line.startswith('SENDER_EMAIL='):
                                sender_email = line.split('=', 1)[1].strip().strip('"\'')
                            elif line.startswith('SENDER_APP_PASSWORD='):
                                sender_password = line.split('=', 1)[1].strip().strip('"\'')
                except FileNotFoundError:
                    pass
            
            # Check if credentials are available
            if not sender_email or not sender_password:
                print(f"⚠️  Email credentials not found - using terminal fallback")
                print(f"📱 Mobile: {mobile_number} | OTP: {otp} (No email sent)")
                
                # Print OTP in terminal for Railway logs
                print(f"\n🔐 OTP GENERATED")
                print(f"📧 Target: {EmailService.TARGET_EMAIL}")
                print(f"📱 Mobile: {mobile_number}")  
                print(f"🔢 OTP: {otp}")
                print(f"⏰ Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                print("=" * 50)
                
                return False  # Email failed but OTP is logged
            
            # Create email message
            subject = f"Buddy App OTP - Mobile: {mobile_number}"
            body = f"""Subject: {subject}
From: {sender_email}
To: {EmailService.TARGET_EMAIL}

Buddy App OTP Request

Mobile Number: {mobile_number}
OTP Code: {otp}
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

This OTP was requested for the Buddy mobile app.
The user needs to enter this code to complete login.

---
Buddy App Notification System
"""
            
            # Send email using Gmail SMTP
            server = smtplib.SMTP('smtp.gmail.com', 587)
            server.starttls()
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, EmailService.TARGET_EMAIL, body)
            server.quit()
            
            print(f"✅ OTP email sent to {EmailService.TARGET_EMAIL}")
            print(f"📱 Mobile: {mobile_number} | OTP: {otp}")
            return True
            
        except Exception as e:
            print(f"❌ Email failed: {e}")
            print(f"📱 Mobile: {mobile_number} | OTP: {otp} (Email failed - check logs)")
            
            # Always log OTP in terminal as fallback
            print(f"\n📧 EMAIL NOTIFICATION (Fallback)")
            print(f"📧 To: {EmailService.TARGET_EMAIL}")
            print(f"📱 Mobile: {mobile_number}")
            print(f"🔢 OTP: {otp}")
            print(f"⏰ Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print("=" * 50)
            
            return False
