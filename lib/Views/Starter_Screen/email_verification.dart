import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmailVerification extends StatefulWidget {
  const EmailVerification({super.key});

  @override
  State<EmailVerification> createState() => _EmailVerificationState();
}

class _EmailVerificationState extends State<EmailVerification> {
  bool isEmailSent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthStateNeedsVerification && state.emailSent) {
            setState(() {
              isEmailSent = true;
            });
          }
        },
        builder: (context, state) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.orange[100]!, Colors.deepOrange[200]!],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 100,
                          color: Colors.deepOrange,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Verify Your Email',
                          
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'We\'ve sent a verification email. Please check your inbox and click the link to verify your account.',
                          textAlign: TextAlign.center,
                          
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () {
                            context.read<AuthBloc>().add(const AuthEventEmailVerification());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('I\'ve Verified My Email'),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: isEmailSent
                              ? null
                              : () {
                                  context.read<AuthBloc>().add(const AuthEventResendVerificationEmail());
                                },
                          child: Text(
                            isEmailSent ? 'Email Sent' : 'Resend Verification Email',
                            style: TextStyle(color: Colors.brown[700]),
                          ),
                        ),
                        if (state is AuthStateNeedsVerification && state.exception != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              'Error: ${state.exception.toString()}',
                              style: TextStyle(color: Colors.red[700]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}