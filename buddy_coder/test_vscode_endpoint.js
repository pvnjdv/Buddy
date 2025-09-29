const axios = require('axios');

async function testVSCodeEndpoint() {
    const baseUrl = 'http://10.31.112.3:8000';
    const mobileNumber = '9270416640';
    const otp = '123456';
    
    try {
        console.log('1. Requesting OTP...');
        const otpResponse = await axios.post(`${baseUrl}/auth/request-otp`, {
            mobile_number: mobileNumber
        });
        console.log('✅ OTP Response:', otpResponse.status);

        console.log('2. Verifying OTP...');
        const verifyResponse = await axios.post(`${baseUrl}/auth/verify-otp`, {
            mobile_number: mobileNumber,
            otp: otp
        });
        
        if (verifyResponse.status === 200 && verifyResponse.data.access_token) {
            console.log('✅ Authentication successful');
            const token = verifyResponse.data.access_token;

            console.log('3. Testing VS Code chat endpoint...');
            const chatResponse = await axios.post(`${baseUrl}/api/vscode/chat`, {
                message: 'Hello from VS Code extension test',
                context: {
                    source: 'vscode_test',
                    timestamp: new Date().toISOString()
                }
            }, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            console.log('✅ VS Code Chat Response:', chatResponse.status);
            console.log('Response:', chatResponse.data.response?.substring(0, 100) + '...');
            
        } else {
            console.log('❌ Authentication failed');
        }
        
    } catch (error) {
        console.error('❌ Test Error:', error.response?.status, error.response?.data || error.message);
    }
}

testVSCodeEndpoint();