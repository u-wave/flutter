import 'package:flutter/material.dart';
import './u_wave/u_wave.dart' show UwaveClient, UwaveCredentials;

typedef SignInCallback = void Function(UwaveCredentials);
class SignInRoute extends StatefulWidget {
  final UwaveClient uwave;
  final SignInCallback onComplete;

  SignInRoute({this.uwave, this.onComplete});

  @override
  _SignInRouteState createState() => _SignInRouteState();
}

class _SignInRouteState extends State<SignInRoute> {
  void _signIn(String email, String password) {
    widget.uwave.signIn(
      email: email,
      password: password,
    ).then((creds) {
      widget.onComplete(creds);
    }).catchError((err) {
      // TODO render this
      print(err);
    });
  }

  void _register(String username, String email, String password) {
    // widget.uwave.createAccount(
    //   username: username,
    //   email: email,
    //   password: password,
    // ).then((_) => _signIn(email, password));
  }

  @override
  Widget build(_) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: <Widget>[
            _SignInForm(onSubmit: _signIn),
            Divider(),
            _RegisterForm(onSubmit: _register),
          ],
        ),
      ),
    );
  }
}

typedef _SignInFormCallback = void Function(String, String);
class _SignInForm extends StatefulWidget {
  final _SignInFormCallback onSubmit;

  _SignInForm({this.onSubmit});

  @override
  _SignInFormState createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _submit() {
    widget.onSubmit(
      _emailController.text,
      _passwordController.text,
    );
  }

  @override
  Widget build(_) {
    final email = TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email',
      ),
      keyboardType: TextInputType.emailAddress,
    );

    final password = TextFormField(
      controller: _passwordController,
      decoration: const InputDecoration(
        labelText: 'Password',
      ),
      obscureText: true,
    );

    final submitButton = Row(
      children: [
        Expanded(
          child: RaisedButton(
            child: Text('Sign In'),
            onPressed: _submit,
          ),
        ),
      ],
    );

    return Column(
      children: <Widget>[
        email,
        password,
        submitButton,
      ],
    );
  }
}

typedef _RegisterFormCallback = void Function(String, String, String);
class _RegisterForm extends StatefulWidget {
  final _RegisterFormCallback onSubmit;

  _RegisterForm({this.onSubmit});

  @override
  _RegisterFormState createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _submit() {
    widget.onSubmit(
      _usernameController.text,
      _emailController.text,
      _passwordController.text,
    );
  }

  @override
  Widget build(_) {
    final username = TextFormField(
      controller: _usernameController,
      decoration: const InputDecoration(
        labelText: 'Username',
      ),
    );

    final email = TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email',
      ),
      keyboardType: TextInputType.emailAddress,
    );

    final password = TextFormField(
      controller: _passwordController,
      decoration: const InputDecoration(
        labelText: 'Password',
      ),
      obscureText: true,
    );

    final submitButton = Row(
      children: [
        Expanded(
          child: RaisedButton(
            child: Text('Register'),
            onPressed: _submit,
          ),
        ),
      ],
    );

    return Column(
      children: <Widget>[
        username,
        email,
        password,
        submitButton,
      ],
    );
  }
}
