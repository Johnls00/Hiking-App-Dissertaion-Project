import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String testEmail = 'john@hotmail.com';
  String testPassword = '1234';

  String savedEmail = '';
  String savedPassword = '';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _checkEmail() {
    setState(() {
      savedEmail = _emailController.text;
      savedPassword = _passwordController.text;
    });

    if (savedEmail == testEmail && savedPassword == testPassword) {
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Color.fromRGBO(241, 244, 248, 1),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            Text(
              "LivingMór Outdoors",
              style: TextStyle(
                fontSize: 35,
                color: Colors.black,
                fontWeight: FontWeight.normal,
              ),
            ),

            // email form
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Form(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (String value) {},
                        validator: (value) {
                          return value!.isEmpty
                              ? 'Please a valid email.'
                              : null;
                        },
                      ),
                    ),

                    SizedBox(height: 16),

                    // password form
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: TextFormField(
                        controller: _passwordController,
                        keyboardType: TextInputType.visiblePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter password',
                          prefixIcon: Icon(Icons.password),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (String value) {},
                        validator: (value) {
                          return value!.isEmpty
                              ? 'Please enter your password.'
                              : null;
                        },
                      ),
                    ),

                    SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: MaterialButton(
                        minWidth: double.infinity,
                        onPressed: () {
                          bool auth = _checkEmail();
                          if (auth) {
                            Navigator.pushNamed(context, '/home');
                          } else {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text("Login Failed"),
                                  content: Text("Incorrect email or password."),
                                  actions: [
                                    TextButton(
                                      child: Text("OK"),
                                      onPressed: () {
                                        Navigator.of(
                                          context,
                                        ).pop(); // Close the popup
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                        },
                        color: Color.fromRGBO(75, 57, 239, 1),
                        textColor: Colors.white,
                        child: Text('Login'),
                      ),
                    ),

                    Text("or"),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: MaterialButton(
                        minWidth: double.infinity,
                        onPressed: () {},
                        color: Colors.white,
                        textColor: Color.fromRGBO(75, 57, 239, 1),
                        child: Text('Sign in with Google'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
