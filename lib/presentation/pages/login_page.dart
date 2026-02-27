import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final FocusNode _usernameFocusNode;
  late final FocusNode _passwordFocusNode;
  late final FocusNode _confirmPasswordFocusNode;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isRegisterMode = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: 'zetempesta');
    _passwordController = TextEditingController(text: '123456');
    _confirmPasswordController = TextEditingController();
    _usernameFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _confirmPasswordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    if (_isRegisterMode) {
      await controller.register(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      return;
    }

    await controller.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF6FAFF),
              Color(0xFFE7EFFB),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: AppColors.shadowBlue,
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Image.asset(
                            'logo_original_ajustada.png',
                            height: 56,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _isRegisterMode
                                ? 'Criar conta no KeepIn'
                                : 'Entrar no KeepIn',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isRegisterMode
                                ? 'Cadastre um novo usuario para acessar o aplicativo.'
                                : 'Use sua conta para acessar suas notas.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _usernameController,
                            focusNode: _usernameFocusNode,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => ref
                                .read(authControllerProvider.notifier)
                                .clearError(),
                            onFieldSubmitted: (_) {
                              _passwordFocusNode.requestFocus();
                            },
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Informe o usuario.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => ref
                                .read(authControllerProvider.notifier)
                                .clearError(),
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Senha',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Informe a senha.';
                              }
                              if (_isRegisterMode && value.length < 6) {
                                return 'Use pelo menos 6 caracteres.';
                              }
                              return null;
                            },
                          ),
                          if (_isRegisterMode) ...<Widget>[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocusNode,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => ref
                                  .read(authControllerProvider.notifier)
                                  .clearError(),
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Confirmar senha',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (!_isRegisterMode) {
                                  return null;
                                }
                                if (value == null || value.isEmpty) {
                                  return 'Confirme a senha.';
                                }
                                if (value != _passwordController.text) {
                                  return 'As senhas nao coincidem.';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (authState.errorMessage != null) ...<Widget>[
                            const SizedBox(height: 16),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4F4),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFFFD6D6),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Text(authState.errorMessage!),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: authState.isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.pureWhite,
                                    ),
                                  )
                                : Text(
                                    _isRegisterMode ? 'Criar conta' : 'Entrar',
                                  ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: authState.isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isRegisterMode = !_isRegisterMode;
                                    });
                                    ref
                                        .read(authControllerProvider.notifier)
                                        .clearError();
                                    _formKey.currentState?.reset();
                                    _confirmPasswordController.clear();
                                  },
                            child: Text(
                              _isRegisterMode
                                  ? 'Ja tem conta? Entrar'
                                  : 'Ainda nao tem conta? Criar agora',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
