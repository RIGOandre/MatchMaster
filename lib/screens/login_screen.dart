import 'package:flutter/material.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/screens/home_shell.dart';
import 'package:matchmaster/widgets/brand.dart';

/// Tela de entrada.
///
/// O login é local: o app não tem servidor, então o campo serve para dar nome
/// ao perfil. A diferença para a versão anterior é que agora ele valida a
/// entrada, guarda o nome e respeita o "Lembrar de mim" — antes o botão
/// "Entrar" seguia adiante mesmo com os campos em branco.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameController.text = AppScope.of(context).settings.userName;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final AppScope scope = AppScope.of(context);
    await scope.settings.setUserName(_nameController.text);
    await scope.settings.setRememberMe(_rememberMe);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 24),
                            const Center(
                              child: BrandLockup(
                                markSize: 64,
                                axis: Axis.vertical,
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              'Seja bem-vindo',
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Marque os pontos, guarde o resultado. '
                              'Tudo fica salvo neste aparelho.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Nome',
                                hintText: 'Como você quer ser chamado',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (String? value) {
                                if ((value ?? '').trim().length < 2) {
                                  return 'Informe pelo menos 2 caracteres.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Mostrar senha'
                                      : 'Ocultar senha',
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (String? value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Informe uma senha.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              value: _rememberMe,
                              onChanged: (bool? value) =>
                                  setState(() => _rememberMe = value ?? false),
                              title: const Text('Lembrar de mim'),
                              subtitle: const Text(
                                'Entrar direto na próxima vez',
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _submit,
                              child: const Text('Entrar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
