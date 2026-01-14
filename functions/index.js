const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Set region for functions
const region = 'us-central1';

// Configure email transporter (using Gmail as example)
// You need to set these environment variables in Firebase Console
// Or use: firebase functions:config:set email.user="your-email@gmail.com" email.password="your-app-password"
const getEmailConfig = () => {
  // Try Firebase config first, then environment variables
  try {
    const config = functions.config();
    if (config.email?.user && config.email?.password) {
      return {
        user: config.email.user,
        pass: config.email.password.replace(/\s+/g, ''), // Remove all spaces from password
      };
    }
  } catch (e) {
    console.log('Firebase config not available, using environment variables');
  }
  
  // Fallback to environment variables
  return {
    user: process.env.EMAIL_USER || 'your-email@gmail.com',
    pass: (process.env.EMAIL_PASSWORD || 'your-app-password').replace(/\s+/g, ''), // Remove all spaces
  };
};

const emailConfig = getEmailConfig();

console.log('Email config loaded. User:', emailConfig.user, 'Password length:', emailConfig.pass?.length || 0);

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: emailConfig.user,
    pass: emailConfig.pass,
  },
});

// Verify transporter configuration
transporter.verify(function (error, success) {
  if (error) {
    console.error('Email transporter verification failed:', error);
  } else {
    console.log('Email transporter is ready to send emails');
  }
});

// Cloud Function to send OTP email
exports.sendOTPEmail = functions.region(region).https.onCall(async (data, context) => {
  // Note: We don't require authentication here because this is called during 2FA flow
  // The user is already authenticated but we're verifying with 2FA
  
  const { email, otp } = data;

  if (!email || !otp) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email and OTP are required'
    );
  }

  try {
    // Email content
    const mailOptions = {
      from: `"RaknaGo" <${emailConfig.user}>`,
      to: email,
      subject: 'Your 2FA Verification Code - RaknaGo',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>2FA Verification Code</title>
        </head>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(135deg, #1E88E5 0%, #1976D2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
            <h1 style="color: white; margin: 0;">RaknaGo</h1>
          </div>
          <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
            <h2 style="color: #1E88E5; margin-top: 0;">Two-Factor Authentication</h2>
            <p>Hello,</p>
            <p>You have requested a verification code for your RaknaGo account. Use the code below to complete your login:</p>
            <div style="background: white; border: 2px solid #1E88E5; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0;">
              <h1 style="color: #1E88E5; font-size: 36px; letter-spacing: 8px; margin: 0; font-family: 'Courier New', monospace;">${otp}</h1>
            </div>
            <p style="color: #666; font-size: 14px;">This code will expire in 5 minutes.</p>
            <p style="color: #666; font-size: 14px;">If you didn't request this code, please ignore this email.</p>
            <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">© ${new Date().getFullYear()} RaknaGo. All rights reserved.</p>
          </div>
        </body>
        </html>
      `,
      text: `Your RaknaGo 2FA Verification Code is: ${otp}\n\nThis code will expire in 5 minutes.\n\nIf you didn't request this code, please ignore this email.`,
    };

    // Send email
    await transporter.sendMail(mailOptions);
    
    console.log(`OTP email sent successfully to ${email}`);

    return { success: true, message: 'OTP email sent successfully' };
  } catch (error) {
    console.error('Error sending OTP email:', error);
    console.error('Error details:', JSON.stringify(error, null, 2));
    
    // Return error with more details for debugging
    throw new functions.https.HttpsError(
      'internal',
      `Failed to send OTP email: ${error.message || error}`,
      error
    );
  }
});

