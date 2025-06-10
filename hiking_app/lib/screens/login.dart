import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose(){
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
            
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Form(
                child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: TextFormField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String value) { 
                                  
                      },
                      validator: (value) {
                        return value!.isEmpty ? 'Please a valid email.' : null;
                      },
                    ),
                  ),
              
                  SizedBox(height: 16,),
              
                  Padding(
                    padding: 
                    const EdgeInsets.symmetric(horizontal: 15),
                    child: TextFormField(
                      keyboardType: TextInputType.visiblePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter password',
                        prefixIcon: Icon(Icons.password),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String value) { 
                                  
                      },
                      validator: (value) {
                        return value!.isEmpty ? 'Please enter your password.' : null;
                      },
                    ),
                  ),

                  SizedBox(height: 16,),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: MaterialButton(
                      minWidth: double.infinity,
                      onPressed: () {
                        Navigator.pushNamed(context, '/home');
                      },
                      color: Color.fromRGBO(75, 57, 239, 1),
                      textColor: Colors.white,
                      child: Text('Login'),
                      ),
                  ),

                  Text(
                    "or"
                  ),

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
              )),
            )
          ],

        ),
      ),
    );
  }
}