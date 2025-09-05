// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hiking_app/widgets/round_back_button.dart';
import 'package:hiking_app/auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  var userNameController = TextEditingController();
  var firstNameController = TextEditingController();
  var lastNameController = TextEditingController();
  var emailController = TextEditingController();
  var passwordController = TextEditingController();

  final firestore = FirebaseFirestore.instance;
  bool _isSubmitting = false;

  @override
  void dispose() {
    userNameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(241, 244, 248, 1),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Back button
              const RoundBackButton(),
              
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fill in your details to get started',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 40),

                    // Username field
                    TextFormField(
                      controller: userNameController,
                      maxLength: 15,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'Enter your username',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // First name field
                    TextFormField(
                      controller: firstNameController,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        hintText: 'Enter your first name',
                        prefixIcon: Icon(Icons.account_circle),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Last name field
                    TextFormField(
                      controller: lastNameController,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        hintText: 'Enter your last name',
                        prefixIcon: Icon(Icons.account_circle_outlined),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Email field
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email address',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Register button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : () async {
                          setState(() => _isSubmitting = true);
                          try {
                            // Basic field validation
                            if (userNameController.text.isEmpty ||
                                firstNameController.text.isEmpty ||
                                lastNameController.text.isEmpty ||
                                emailController.text.isEmpty ||
                                passwordController.text.isEmpty) {
                              throw FormatException('Please fill in all fields');
                            }
                            if (passwordController.text.length < 6) {
                              throw FormatException('Password should be at least 6 characters');
                            }

                            // Create auth user and get UID
                            final userId = await Auth().createUserWithEmailAndPassword(
                              email: emailController.text.trim(),
                              password: passwordController.text,
                            );

                            if (userId == null || userId.isEmpty) {
                              throw FirebaseAuthException(
                                code: 'user-null',
                                message: 'User creation failed. No UID returned.',
                              );
                            }

                            // Write profile doc using UID as the document id (do NOT store password)
                            await firestore.collection('users').doc(userId).set({
                              'userID': userId,
                              'userName': userNameController.text.trim(),
                              'firstName': firstNameController.text.trim(),
                              'lastName': lastNameController.text.trim(),
                              'email': emailController.text.trim().toLowerCase(),
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            if (!mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Account created successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // Navigate back to login screen
                            Navigator.of(context).pushReplacementNamed('/login');
                          } on FirebaseAuthException catch (e) {
                            if (!mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            String msg;
                            switch (e.code) {
                              case 'email-already-in-use':
                                msg = 'That email is already registered.';
                                break;
                              case 'invalid-email':
                                msg = 'Please enter a valid email address.';
                                break;
                              case 'weak-password':
                                msg = 'Password is too weak.';
                                break;
                              default:
                                msg = e.message ?? 'Authentication error.';
                            }
                            messenger.showSnackBar(
                              SnackBar(content: Text(msg), backgroundColor: Colors.red),
                            );
                          } on FormatException catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error creating account: $e'), backgroundColor: Colors.red),
                            );
                          } finally {
                            if (mounted) setState(() => _isSubmitting = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(75, 57, 239, 1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Back to login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(color: Colors.black54),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color.fromRGBO(75, 57, 239, 1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
