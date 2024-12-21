// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:samadhan_chat/Auth/Bloc/auth_bloc.dart';
// import 'package:samadhan_chat/Auth/Bloc/auth_state.dart';
// import 'package:samadhan_chat/ErrorHandeling/error_translator.dart';
// import 'package:samadhan_chat/utilities/Dialogs/show_message.dart';

// mixin ErrorHandlingMixin<T extends StatefulWidget> on State<T> {
//   void setupErrorHandling(BuildContext context) {
//     String message = '';
//     BlocListener<AuthBloc, AuthState>(
//       listener: (context, state) {
//         switch (state) {
//           case AuthStateLoggedOut():
//           if (state.exception != null) {
//              message = ErrorTranslator.translate(state.exception!);}
//           case AuthStateLoggedIn():
//             if (state.exception != null) {
//              message = ErrorTranslator.translate(state.exception!);}
//           case AuthStateRegistering():
//             if (state.exception != null) {
//              message = ErrorTranslator.translate(state.exception!);}
//           case AuthStateNeedsVerification():
//             if (state.exception != null) {
//              message = ErrorTranslator.translate(state.exception!);}
//           case AuthStateForgotPassword():
//             if (state.exception != null) {
//              message = ErrorTranslator.translate(state.exception!);}
//         }
//         if (message.isNotEmpty) {
//           showMessage(
//             message: message,
//             context: context,
//             icon: Icons.error,
//             backgroundColor: Colors.red.withOpacity(0.8),
//           );
//         }
//       },
//       child: Container(), // This child will be ignored as we're using this mixin
//     );
//   }
// }