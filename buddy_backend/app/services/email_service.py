import smtplib
import os
from datetime import datetime

class EmailService:
    """Simple email service to send OTP to fixed email for testing"""
    
    TARGET_EMAIL = "p8975306526@gmail.com"
    
    @staticmethod
    def send_otp_email(mobile_number: str, otp: str) -> bool:
        """
        Send OTP to fixed email address for testing
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
                            if line.startswith('SENDER_EMAIL='):
                                sender_email = line.split('=', 1)[1].strip()
                            elif line.startswith('SENDER_APP_PASSWORD='):
                                sender_password = line.split('=', 1)[1].strip()
                except FileNotFoundError:
                    pass
            
            # Check if credentials are available
            if not sender_email or not sender_password:
                print(f"⚠️  Email credentials not found - using terminal fallback")
                raise Exception("Email credentials not configured")
            
            # Simple email message
            subject = f"Buddy App OTP - Mobile: {mobile_number}"
            body = f"""Subject: {subject}

Buddy App OTP Request

Mobile Number: {mobile_number}
OTP Code: {otp}
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

Enter this OTP in your app to login.
"""
            
            # Send email using simple SMTP
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
            print(f"📱 Mobile: {mobile_number} | OTP: {otp} (fallback to console)")
            
            # Fallback: Print in terminal format
            print(f"\n📧 EMAIL NOTIFICATION (Fallback)")
            print(f"📧 To: {EmailService.TARGET_EMAIL}")
            print(f"📱 Mobile: {mobile_number}")
            print(f"🔢 OTP: {otp}")
            print(f"⏰ Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"=" * 50)
            
            return False
            body = f"""
Buddy App OTP Request

Mobile Number: {mobile_number}
OTP Code: {otp}
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

Enter this OTP in your app to login.
            """
            
            msg.attach(MimeText(body, 'plain'))
            
            # Send email using Gmail SMTP
            server = smtplib.SMTP('smtp.gmail.com', 587)
            server.starttls()
            server.login(sender_email, sender_password)
            text = msg.as_string()
            server.sendmail(sender_email, EmailService.TARGET_EMAIL, text)
            server.quit()
            
            print(f"✅ OTP email sent to {EmailService.TARGET_EMAIL}")
            print(f"📱 Mobile: {mobile_number} | OTP: {otp}")
            return True
            
        except Exception as e:
            print(f"❌ Email failed: {e}")
            print(f"📱 Mobile: {mobile_number} | OTP: {otp} (fallback to console)")
            return False
