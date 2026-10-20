//import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:icebreaker/main.dart';
import 'package:icebreaker/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Login',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 50),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: LoginForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
      

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
  });


  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {

  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  bool isLoading = false;

bool verifyPassword(String enteredPassword, String storedHash) {
  return BCrypt.checkpw(enteredPassword, storedHash);
}

Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('jwt_token', token);
}

  // String hashPassword(String password) {
  // return BCrypt.hashpw(password, BCrypt.gensalt());
  // }

Future<void> login() async {
  if (!_formKey.currentState!.validate()) return;
  _formKey.currentState!.save();

  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (response.user != null) {
      // Save the JWT token to local storage
      String token = response.session!.accessToken;
      await saveToken(token);

      userId = response.user!.id;


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login successful!',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    }
  } on AuthException catch (e) {
    // Supabase throws AuthException
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Incorrect email or password",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  } catch (e) {
    // Catch any other errors
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Something went wrong. Please try again.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),

      child:   
      Container(
        decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black),
        borderRadius: BorderRadius.circular(8.0), 
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key : _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Email',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                  onChanged: (value) => email = value,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 25),
            
            
                Text(
                    'Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextFormField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                  onChanged: (value) => password = value,
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Enter a password' : null,
                ),
                SizedBox(height: 25),
            
            
                ElevatedButton(
                onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      login();
                    }
                  }, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0), 
                  ),
                ),
                child: Text(
                  'Login',
                  style: TextStyle(color: theme.colorScheme.brightness == Brightness.dark ? Colors.black : Colors.white),
                ),
              ),
              SizedBox(height: 25),
            
            
              ElevatedButton(
                onPressed: () {
                  //take to SignUpPage
                  Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignUpPage()),
                       );
                }, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0), 
                  ),
                ),
                child: Text(
                  'Sign Up',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              SizedBox(height: 10),
            
            
              TextButton(
                onPressed: () {
                  //take to forgot password page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ForgotPage()),
                  );
                },
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Adjust layout when keyboard appears
      appBar: AppBar(),
      body: SingleChildScrollView(

          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 80),
              SignUpForm(),
              SizedBox(height: 350),
            ],
          ),
        
      ),
    );
  }
}

class SignUpForm extends StatefulWidget {
  const SignUpForm({
    super.key,
  });

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  String username = '';
  String email = '';
  String password = '';
  String confirm = '';
  bool isLoading = false;

  String hashPassword(String password) {
  return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  Future<void> signUp() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    
    _formKey.currentState!.save();
    setState(() => isLoading = true);
    
    try {
      String hashed = hashPassword(password);

      final response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      );

    if (response.user == null) {
      throw Exception("Signup failed. Please try again.");
    }

      await supabase.from('Users').insert({
        'user_id': response.user!.id,
        'username': username,
        'email': email,
        'password': hashed,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
      content: Text(
        'Sign Up successful!',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      backgroundColor: Colors.green, // Success color
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );

    } catch (error) {
      if (!mounted) return;

      String errorMessage = 'Error: ${error.toString()}';

    if (error.toString().contains('email')) {
      if (error.toString().contains('already')) {
        errorMessage = 'Email is already in use. Please try another email.';
        
      } else if (error.toString().contains('invalid')) {
        errorMessage = 'Invalid email format. Please enter a valid email address.';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Row(
        children: [
          Icon(Icons.error, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red, 
      duration: Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      )
    );
    }

    if (mounted) {
    setState(() => isLoading = false);
  }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return  Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),

      child:   
      Container(
        decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black),
        borderRadius: BorderRadius.circular(8.0), 
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Username',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    counterText: '',
                  ),
                  maxLength: 30,
                  onChanged: (value) => username = value,
                  // minimum username lengh of 3 characters
                  validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Username is required'
                        : value.trim().length < 3
                            ? 'Username must be at least 3 characters'
                            : null,
                ),
                SizedBox(height: 25),
            
                Text(
                    'Email',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                  onChanged: (value) => email = value,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 25),
            
                Text(
                    'Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                  onChanged: (value) => setState(() => password = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a valid password';
                    } 
                    else if (value.length < 7) {
                      return 'Must be at least 7 characters';
                    } 
                    else if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
                      return 'Must contain at least one letter';
                    }
                    else if (!RegExp(r'\d').hasMatch(value)) {
                      return 'Must contain at least one number';
                    }
                    else if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                      return 'Must contain at least one special character';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 25),
            
                Text(
                    'Confirm Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                  onChanged: (value) => setState(() => confirm = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    } else if (value != password) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 25),
            
                ElevatedButton(
                onPressed: isLoading ? null : signUp, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0), 
                  ),
                ),
                child: Text(
                  'Sign Up',
                  style: TextStyle(color: theme.colorScheme.brightness == Brightness.dark ? Colors.black : Colors.white),
                ),
              ),
              SizedBox(height: 10),
              ],
            ),
          ),
      ),
      ),
    );
  }
}

class ForgotPage extends StatelessWidget {
  const ForgotPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Forgot Password',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
          ),
          SizedBox(height: 80),
          ForgotForm(),
        ],
      ),
    );
  }
}

class ForgotForm extends StatefulWidget {
  const ForgotForm({
    super.key,
  });

  @override
  State<ForgotForm> createState() => _ForgotFormState();
}

class _ForgotFormState extends State<ForgotForm> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),

      child:   
      SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(8.0), 
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key : _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Email',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 25),
              
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final email = _emailController.text.trim();


                        // Check if the email exists in Users
                        final response = await Supabase.instance.client
                            .from('Users')
                            .select('email')
                            .eq('email', email)
                            .maybeSingle();

                        if (response == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Account does not exist for $email'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        try {
                          await Supabase.instance.client.auth.resetPasswordForEmail(
                            email,
                            redirectTo: 'https://ibpasswordreset.onrender.com/reset',
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Email Sent',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        } catch (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $error'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      'Send Email for Password Reset',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),


                SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}