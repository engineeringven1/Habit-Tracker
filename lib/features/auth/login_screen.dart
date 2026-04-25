import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthView { form, awaitingConfirmation }

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;
  _AuthView _view = _AuthView.form;
  String _pendingEmail = '';
  String _pendingPassword = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (mounted) context.go('/tracker');
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('not confirmed') || msg.contains('email not confirmed')) {
        _showEmailNotConfirmedError(email, password);
      } else {
        _showError(_translateAuthError(e.message));
      }
    } catch (_) {
      _showError('Ocurrió un error inesperado');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _translateAuthError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('rate limit') || m.contains('rate_limit')) {
      return 'Límite de emails alcanzado. Espera unos minutos e intenta de nuevo.';
    }
    if (m.contains('not confirmed') || m.contains('email not confirmed')) {
      return 'Debes confirmar tu correo antes de iniciar sesión.';
    }
    if (m.contains('already registered') || m.contains('user already')) {
      return 'Este email ya está registrado. Inicia sesión.';
    }
    if (m.contains('invalid login') || m.contains('invalid credentials') ||
        m.contains('invalid email or password')) {
      return 'Email o contraseña incorrectos.';
    }
    if (m.contains('weak password') || m.contains('password should be')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (m.contains('unable to validate') || m.contains('otp expired')) {
      return 'El link de confirmación expiró. Solicita uno nuevo.';
    }
    return msg;
  }

  void _showEmailNotConfirmedError(String email, String password) {
    setState(() {
      _pendingEmail = email;
      _pendingPassword = password;
      _view = _AuthView.awaitingConfirmation;
    });
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Ingresa tu email y contraseña para registrarte');
      return;
    }
    if (password.length < 6) {
      _showError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _supabase.auth.signUp(email: email, password: password);
      if (!mounted) return;
      if (res.session != null) {
        // Email confirmation disabled — logged in immediately
        context.go('/tracker');
      } else {
        // Email confirmation required
        setState(() {
          _pendingEmail = email;
          _pendingPassword = password;
          _view = _AuthView.awaitingConfirmation;
        });
      }
    } on AuthException catch (e) {
      _showError(_translateAuthError(e.message));
    } catch (_) {
      _showError('Ocurrió un error inesperado');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkConfirmed() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _pendingEmail,
        password: _pendingPassword,
      );
      if (mounted) context.go('/tracker');
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('not confirmed') || msg.contains('email not confirmed')) {
        _showError('Todavía no confirmaste tu correo. Revisa bandeja de entrada y spam.');
      } else {
        _showError(_translateAuthError(e.message));
      }
    } catch (_) {
      _showError('Ocurrió un error inesperado');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendConfirmation() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: _pendingEmail,
      );
      if (mounted) _showSuccess('Correo reenviado. Revisa tu bandeja de entrada.');
    } on AuthException catch (e) {
      _showError(_translateAuthError(e.message));
    } catch (_) {
      _showError('No se pudo reenviar el correo');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _backToForm() {
    setState(() => _view = _AuthView.form);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppColors.dangerColor),
        ),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppColors.successColor),
        ),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _view == _AuthView.awaitingConfirmation
              ? _ConfirmEmailView(
                  key: const ValueKey('confirm'),
                  email: _pendingEmail,
                  isLoading: _isLoading,
                  onConfirmed: _checkConfirmed,
                  onResend: _resendConfirmation,
                  onBack: _backToForm,
                )
              : _FormView(
                  key: const ValueKey('form'),
                  emailController: _emailController,
                  passwordController: _passwordController,
                  passwordVisible: _passwordVisible,
                  isLoading: _isLoading,
                  onTogglePassword: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  onSignIn: _signIn,
                  onSignUp: _signUp,
                ),
        ),
      ),
    );
  }
}

// ─── Form view ────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  const _FormView({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.passwordVisible,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildLogoIcon()
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),
          const SizedBox(height: 24),
          Text(
            'Habit OS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          )
              .animate(delay: 150.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),
          const SizedBox(height: 8),
          Text(
            'Tu sistema de alto rendimiento',
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary),
          )
              .animate(delay: 300.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),
          const SizedBox(height: 40),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.inter(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined,
                  color: AppColors.textSecondary, size: 20),
            ),
          )
              .animate(delay: 450.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: !passwordVisible,
            style: GoogleFonts.inter(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Contraseña',
              prefixIcon: Icon(Icons.lock_outline,
                  color: AppColors.textSecondary, size: 20),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          )
              .animate(delay: 600.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.primaryAccent),
              ),
            ),
          )
              .animate(delay: 750.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Iniciar sesión',
            gradient: AppColors.gradientPrimary,
            onPressed: onSignIn,
            isLoading: isLoading,
          )
              .animate(delay: 900.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '¿No tienes cuenta? ',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: isLoading ? null : onSignUp,
                child: Text(
                  'Regístrate',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryAccent,
                  ),
                ),
              ),
            ],
          )
              .animate(delay: 1050.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildLogoIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.gradientPrimary,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryAccent.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(Icons.bolt, size: 40, color: Colors.white),
    );
  }
}

// ─── Awaiting email confirmation view ─────────────────────────────────────────

class _ConfirmEmailView extends StatelessWidget {
  final String email;
  final bool isLoading;
  final VoidCallback onConfirmed;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const _ConfirmEmailView({
    super.key,
    required this.email,
    required this.isLoading,
    required this.onConfirmed,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.successColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.mark_email_unread_rounded,
                size: 40, color: AppColors.successColor),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.8, 0.8), duration: 500.ms),
          const SizedBox(height: 28),
          Text(
            'Confirma tu correo',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 12),
          Text(
            'Te enviamos un correo de confirmación a',
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ).animate(delay: 180.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 6),
          Text(
            email,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryAccent,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 220.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primaryAccent.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Step(
                  number: '1',
                  text: 'Abre tu bandeja de entrada (revisa también Spam)',
                ),
                const SizedBox(height: 10),
                _Step(
                  number: '2',
                  text: 'Haz clic en el link "Confirmar cuenta" del correo',
                ),
                const SizedBox(height: 10),
                _Step(
                  number: '3',
                  text:
                      'Vuelve aquí y pulsa "Ya confirmé mi correo"',
                ),
              ],
            ),
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 28),
          GradientButton(
            label: 'Ya confirmé mi correo',
            gradient: AppColors.gradientPrimary,
            onPressed: onConfirmed,
            isLoading: isLoading,
          ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onResend,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Reenviar correo de confirmación',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ).animate(delay: 480.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 14),
          TextButton(
            onPressed: isLoading ? null : onBack,
            child: Text(
              'Volver al inicio de sesión',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ).animate(delay: 540.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryAccent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }
}
