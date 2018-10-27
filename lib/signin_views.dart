import 'package:flutter/material.dart';
import './u_wave/announce.dart' show UwaveServer;
import './u_wave/u_wave.dart' show UwaveClient, UwaveCredentials;

typedef SignInCallback = void Function(UwaveCredentials);
class SignInRoute extends StatefulWidget {
  final UwaveServer server;
  final UwaveClient uwave;
  final SignInCallback onComplete;

  const SignInRoute({this.server, this.uwave, this.onComplete})
      : assert(server != null),
        assert(uwave != null),
        assert(onComplete != null);

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
      debugPrint(err);
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
        title: Text('Sign In to ${widget.server.name}'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(widget.server.subtitle),
              ),

              _SignInForm(onSubmit: _signIn),
              const Divider(),
              _RegisterForm(onSubmit: _register),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _SignInFormCallback = void Function(String, String);
class _SignInForm extends StatefulWidget {
  final _SignInFormCallback onSubmit;

  const _SignInForm({this.onSubmit}) : assert(onSubmit != null);

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
    final email = StyledField(
      child: TextFormField(
        controller: _emailController,
        decoration: const InputDecoration(
          labelText: 'Email',
          suffixIcon: Icon(Icons.email),
        ),
        keyboardType: TextInputType.emailAddress,
      ),
    );

    final password = StyledField(
      child: TextFormField(
        controller: _passwordController,
        decoration: const InputDecoration(
          labelText: 'Password',
          suffixIcon: Icon(Icons.lock),
        ),
        obscureText: true,
      ),
    );

    final submitButton = Row(
      children: [
        Expanded(
          child: RaisedButton(
            color: Theme.of(context).primaryColor,
            child: const Text('Sign In'),
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

  const _RegisterForm({this.onSubmit}) : assert(onSubmit != null);

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
    final username = StyledField(
      child: TextFormField(
        controller: _usernameController,
        decoration: const InputDecoration(
          labelText: 'Username',
          suffixIcon: Icon(Icons.person),
        ),
      ),
    );

    final email = StyledField(
      child: TextFormField(
        controller: _emailController,
        decoration: const InputDecoration(
          labelText: 'Email',
          suffixIcon: Icon(Icons.email),
        ),
        keyboardType: TextInputType.emailAddress,
      ),
    );

    final password = StyledField(
      child: TextFormField(
        controller: _passwordController,
        decoration: const InputDecoration(
          labelText: 'Password',
          suffixIcon: Icon(Icons.lock),
        ),
        obscureText: true,
      ),
    );

    final submitButton = Row(
      children: [
        Expanded(
          child: RaisedButton(
            color: Theme.of(context).primaryColor,
            child: const Text('Register'),
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

class StyledField extends StatelessWidget {
  final Widget child;

  const StyledField({this.child}) : assert(child != null);

  @override
  Widget build(BuildContext context) {
    const borderLight = BorderSide(width: 1.0, color: Color(0xFF3E3E3E));
    const borderDark = BorderSide(width: 1.0, color: Color(0xFF2C2C2C));
    const border = Border(
      top: borderLight,
      bottom: borderDark,
      left: borderDark,
      right: borderLight,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF383838),
        border: border,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
